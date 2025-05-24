import SQLite// 导入SQLite数据库操作库
import Foundation  // 导入基础系统库



/// 数据库管理单例类，负责数据库连接、初始化、数据导入和查询操作
class DatabaseManager {
    /// 单例实例，确保全局唯一访问点
    static let shared = DatabaseManager()
    
    /// 数据库连接对象（SQLite的Connection类型）
    private var db: Connection?
    /// 初始化状态标记（避免重复初始化）
    private var isInitialized = false
    
    // MARK: - 数据库表结构定义（私有属性）
    
    /// 目标数据表（对应SQLite中的area_table）
    private let areaTable = Table("area_table")
    /// 数据表中的"chinese_name"列（字符串类型，主键）
    private let chineseName = Expression<String>("chinese_name")
    /// 数据表中的"adcode"列（行政区划代码，字符串类型）
    private let adcode = Expression<String>("adcode")
    /// 数据表中的"citycode"列（城市区号，可选字符串类型）
    private let citycode = Expression<String?>("citycode")
    
    // MARK: - 初始化方法（私有，防止外部直接创建实例）
    
    /// 初始化数据库连接（私有构造方法）
    private init() {
        do {
            // 获取Documents目录路径（用于存储数据库文件）
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            // 拼接数据库文件完整路径（文件名：AMap_adcode_citycode_utf8.db）
            let dbPath = fileURL.appendingPathComponent("AMap_adcode_citycode_utf8.db").path
          //  print("数据库文件路径: \(dbPath)")
            
            // 尝试连接数据库文件（若不存在则自动创建）
            db = try Connection(dbPath)
        } catch {
            // 连接失败时打印错误信息
            print("数据库连接失败: \(error)")
        }
    }
    
    // MARK: - 核心功能：确保数据库初始化
    
    /// 确保数据库已初始化（创建表并导入数据）
    /// - 若已初始化过，直接返回
    /// - 若未初始化，依次执行建表和数据导入
    func ensureInitialized() throws {
        guard !isInitialized else { return }  // 避免重复初始化
        
        try setupDatabase()       // 步骤1：创建数据表
        try importDataFromCSV()   // 步骤2：从CSV导入数据
        
        isInitialized = true      // 标记初始化完成
        print("数据库初始化完成")
    }
    
    // MARK: - 建表操作
    
    /// 创建数据表（若不存在）
    /// - 表结构包含三列：chinese_name（主键）、adcode、citycode
    /// - 抛出DatabaseError.connectionFailed：数据库连接失败时
    func setupDatabase() throws {
        guard let db = db else { throw DatabaseError.connectionFailed }  // 检查数据库连接
        
        do {
            // 执行建表操作（ifNotExists: true 避免重复建表）
            try db.run(areaTable.create(ifNotExists: true) { t in
                t.column(chineseName, primaryKey: true)  // 主键列（唯一标识）
                t.column(adcode)                         // 行政区划代码列
                t.column(citycode)                       // 城市区号列（可选）
            })
            print("表创建成功: area_table")
        } catch {
            // 建表失败时打印错误并抛出
            print("表创建失败: \(error)")
            throw error
        }
    }
    
    // MARK: - 数据导入（从CSV文件）
    
    /// 从CSV文件导入行政区划数据到数据库
    /// - 步骤：读取CSV → 解析行 → 过滤无效数据 → 去重插入 → 统计结果
    /// - 抛出DatabaseError.fileNotFound：CSV文件未找到时
    /// - 抛出DatabaseError.connectionFailed：数据库连接失败时
    ///
    func importDataFromCSV() throws {
        _ = Date()  // 记录导入开始时间（用于性能统计）
        guard let db = db else { throw DatabaseError.connectionFailed }  // 检查数据库连接
        
        // 步骤1：获取CSV文件路径（从应用Bundle中查找）
        guard let csvURL = Bundle.main.url(forResource: "AMap_adcode_citycode_utf8", withExtension: "CSV") else {
          //  print("CSV文件未找到")
            throw DatabaseError.fileNotFound
        }
       // print("开始导入数据，CSV路径: \(csvURL.path)")
        
        // 步骤2：读取CSV文件内容（UTF-8编码）
        let csvData = try String(contentsOf: csvURL, encoding: .utf8)
        let rows = csvData.components(separatedBy: .newlines)  // 按换行符分割行
        
        // 步骤3：初始化统计变量（成功/跳过记录数）
        let areaTable = Table("area_table")
        var successCount = 0  // 成功插入记录数
        var skipCount = 0     // 跳过记录数（无效/重复/特殊数据）
        
        // 步骤4：使用事务批量插入（提高写入效率）
        try db.transaction {
            for (index, row) in rows.enumerated() where index > 0 {  // 跳过首行表头（index=0）
                // 过滤空行
                guard !row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                // 按逗号分割列，并去除首尾空格
                let columns = row.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                // 过滤列数不足的无效行（至少需要chinese_name和adcode两列）
                guard columns.count >= 2 else {
                  //  print("忽略格式不正确的行 \(index): \(row)")
                    skipCount += 1
                    continue
                }
                
                let name = columns[0]  // 地区名称（chinese_name）
                
                // 跳过特殊国家名称（如"中华人民共和国"，非具体行政区划）
                if name == "中华人民共和国" {
                   // print("跳过国家名称行: \(name)")
                    skipCount += 1
                    continue
                }
                
                // 去重检查：查询是否已存在同名记录
                let query = areaTable.filter(chineseName == name)
                if let _ = try? db.pluck(query) {
                    //print("记录已存在，跳过: \(name)")
                    skipCount += 1
                    continue
                }
                
                // 执行插入操作
                do {
                    let insert = areaTable.insert(
                        chineseName <- name,          // 地区名称
                        adcode <- columns[1],         // 行政区划代码
                        citycode <- (columns.count > 2 ? columns[2] : nil)  // 城市区号（可选）
                    )
                    try db.run(insert)  // 执行插入
                    successCount += 1   // 成功数+1
                } catch {
                    // 插入失败时打印错误并抛出（终止当前事务）
                   // print("插入第 \(index) 行失败: \(error)，数据: \(row)")
                    throw error
                }
            }
        }
        
        // 打印导入结果和耗时统计
       // print("数据导入完成 - 成功: \(successCount)条, 跳过: \(skipCount)条")
        _ = Date()
       // print("数据导入总耗时: \(endTime.timeIntervalSince(startTime)) 秒")
    }
    
    // MARK: - 数据查询（根据地区名称获取adcode）
    
    /// 根据地区名称查询对应的行政区划代码（adcode）
    /// - 参数name：地区名称（如"番禺区"）
    /// - 返回值：匹配的adcode（若存在），否则nil
    func getAdcode(forName name: String) -> String? {
        do {
            print("开始查询地区: \(name)")
            try ensureInitialized()  // 确保数据库已初始化
            
            guard let db = db else {
           //     print("数据库连接不存在")
                return nil
            }
            
            // 构建查询条件（按地区名称过滤）
            let query = areaTable.filter(chineseName == name)
            
            // 执行查询并解析结果
            if let row = try db.pluck(query) {
                let result = row[chineseName]  // 从结果行中提取adcode
              //  print("查询成功: \(name) -> \(result)")
                return result
            } else {
              //  print("未在数据库中找到记录: \(name)")
                return nil
            }
        } catch {
           // print("查询过程中发生错误: \(error)")
            return nil
        }
    }
    
    // MARK: - 数据库重置（删除表并重新初始化）
    
    /// 重置数据库（删除现有表并重新初始化）
    /// - 用于数据损坏或需要重新导入时
    /// - 抛出DatabaseError.connectionFailed：数据库连接失败时
    func resetDatabase() throws {
        guard let db = db else { throw DatabaseError.connectionFailed }  // 检查数据库连接
        
        do {
            // 步骤1：删除现有表（ifExists: true 避免表不存在时出错）
            try db.run(areaTable.drop(ifExists: true))
            print("已删除表: area_table")
            
            // 步骤2：重新建表并导入数据
            try setupDatabase()
            try importDataFromCSV()
            print("数据库已重置并重新导入数据")
        } catch {
            // 重置失败时打印错误并抛出
            print("重置数据库失败: \(error)")
            throw error
        }
    }
    
    
    // 精确匹配（用于验证用户选择）
    func getRegionName(byName name: String) -> String? {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return nil }
        
        guard let db = db else {
            print("数据库连接不存在")
            return nil
        }
        
        do {
            let query = areaTable.filter(chineseName == cleanedName)
            if let row = try db.pluck(query) {
                return row[chineseName]
            }
            return nil
        } catch {
            print("数据库查询错误: \(error)")
            return nil
        }
    }
    
    // 模糊搜索（用于推荐）
    func searchRegionsName(_ query: String) -> [String] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return [] }
        
        guard let db = db else {
            print("数据库连接不存在")
            return []
        }
        
        do {
            // 执行模糊查询，获取所有包含关键词的地区
            let fuzzyQuery = areaTable.filter(chineseName.like("%\(cleanedQuery)%"))
            let results = try db.prepare(fuzzyQuery).map { row -> String in
                return row[chineseName]
            }
            
            // 按匹配度排序：前缀匹配 > 包含匹配
            let prefixMatches = results.filter { $0.hasPrefix(cleanedQuery) }
            let containsMatches = results.filter {
                $0.contains(cleanedQuery) && !prefixMatches.contains($0)
            }
            
            return prefixMatches + containsMatches
        } catch {
            print("数据库查询错误: \(error)")
            return []
        }
    }
    
    /// 根据行政区划代码（adcode）获取对应的城市名称
    /// - 参数adcode：行政区划代码
    /// - 返回值：匹配的城市名称（若存在），否则nil
    func getCityNameByAdcode(_ adcode: String) -> String? {
        do {
            try ensureInitialized()  // 确保数据库已初始化
            
            guard let db = db else {
                return nil
            }
            
            // 构建查询条件（按行政区划代码过滤）
            let query = areaTable.filter(self.adcode == adcode)
            
            // 执行查询并解析结果
            if let row = try db.pluck(query) {
                let result = row[chineseName]  // 从结果行中提取城市名称
                return result
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
}
