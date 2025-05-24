//
//  WeatherEntityService.swift
//  MyWeatherApp
//
//  Created by Star. on 2025/5/22.
//

import Foundation
import CoreData

class WeatherDataStorage: ObservableObject {
    // 单例模式，保证全局唯一实例
    static let shared = WeatherDataStorage()
    // Core Data持久化容器
    let persistentContainer: NSPersistentContainer
    
    init() {
        // 初始化持久化容器，名称需与.xcdatamodeld文件名称一致
        persistentContainer = NSPersistentContainer(name: "WeatherCoreData")
        // 加载持久化存储
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("加载Core Data失败: \(error)")
            }
        }
    }
    
    // 获取视图上下文
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
}

extension WeatherDataStorage {
    // 获取城市天气数据
    func getCityWeather(for adcode: String) -> (CityEntity?, CurrentWeatherEntity?, [ForecastEntity]?) {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<CityEntity> = CityEntity.fetchRequest()
        request.predicate = NSPredicate(format: "adcode == %@", adcode)
        
        do {
            let cities = try context.fetch(request)
            guard let city = cities.first else {
                print("📱 [CoreData] 未找到本地存储的城市数据 - adcode: \(adcode)")
                return (nil, nil, nil)
            }
            let forecasts = city.forecasts?.allObjects as? [ForecastEntity]
            print("💾 [CoreData] 从本地数据库读取缓存 - 城市: \(city.name ?? "未知")")
            return (city, city.currentWeather, forecasts?.sorted(by: { $0.date ?? Date.distantPast < $1.date ?? Date.distantPast }))
        } catch {
            print("❌ [CoreData] 读取本地数据失败 - \(error)")
            return (nil, nil, nil)
        }
    }
    
    // 保存城市天气数据
    func saveCityWeather(_ cityWeather: CityWeatherModel) {
        print("💾 [CoreData] 开始将网络数据保存到本地数据库 - \(cityWeather.city)")
        let context = persistentContainer.viewContext
        // 遍历每个城市的数据
        for (index, cityName) in cityWeather.city.enumerated() {
            guard index < cityWeather.live.count,
                    index < cityWeather.future.count else { continue }
            let liveData = cityWeather.live[index]
            let forecastData = cityWeather.future[index]
            // 查找或创建城市实体
            let city = findOrCreateCity(in: context, name: cityName, adcode: liveData.adcode)
            // 更新当前天气
            updateCurrentWeather(in: context, city: city, liveData: liveData)
            // 更新预报数据
            updateForecasts(in: context, city: city, dailyForecasts: [forecastData])
        }
        // 保存上下文
        saveContext(context)
        print("✅ [CoreData] 网络数据已保存到本地数据库")
    }
    
    // 查找或创建城市实体
    private func findOrCreateCity(in context: NSManagedObjectContext, name: String, adcode: String) -> CityEntity {
        let request: NSFetchRequest<CityEntity> = CityEntity.fetchRequest()
        request.predicate = NSPredicate(format: "adcode == %@", adcode)
        do {
            if let existingCity = try context.fetch(request).first {
                print("📱 [CoreData] 在本地数据库中找到城市 - \(name)")
                return existingCity
            }
        } catch {
            print("❌ [CoreData] 查询本地数据库失败 - \(error)")
        }
        // 创建新城市
        print("➕ [CoreData] 在本地数据库创建新城市 - \(name)")
        let city = CityEntity(context: context)
        city.id = UUID()
        city.name = name
        city.adcode = adcode
        city.province = "" // 后续可从API获取填充
        city.lastUpdated = Date()
        return city
    }
    
    // 更新当前天气
    private func updateCurrentWeather(in context: NSManagedObjectContext, city: CityEntity, liveData: WeatherLiveModel.LiveData) {
        // 如果已有当前天气，更新它；否则创建新的
        let currentWeather: CurrentWeatherEntity
        if let existingWeather = city.currentWeather {
            print("📝 [CoreData] 更新本地数据库中的天气数据 - \(city.name ?? "")")
            currentWeather = existingWeather
        } else {
            print("➕ [CoreData] 在本地数据库创建新天气数据 - \(city.name ?? "")")
            currentWeather = CurrentWeatherEntity(context: context)
            currentWeather.id = UUID()
            currentWeather.city = city
            city.currentWeather = currentWeather
        }
        // 从模型更新属性
        currentWeather.weather = liveData.weather
        currentWeather.temperature = Double(liveData.temperature) ?? 0
        currentWeather.windDirection = liveData.winddirection
        currentWeather.windPower = liveData.windpower
        currentWeather.humidity = Double(liveData.humidity) ?? 0
        // 转换日期格式
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        currentWeather.reportTime = dateFormatter.date(from: liveData.reporttime) ?? Date()
    }
    
    // 更新预报数据
    private func updateForecasts(in context: NSManagedObjectContext, city: CityEntity, dailyForecasts: [WeatherFutureModel.ForecastData.DailyForecast]) {
        // 清除旧的预报
        if let oldForecasts = city.forecasts?.allObjects as? [ForecastEntity] {
            print("🗑 [CoreData] 清除本地数据库中的旧预报数据 - \(oldForecasts.count) 条")
            oldForecasts.forEach { context.delete($0) }
        }
        // 添加新的预报
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        for forecast in dailyForecasts {
            print("➕ [CoreData] 在本地数据库添加新预报 - \(forecast.date)")
            let cdForecast = ForecastEntity(context: context)
            cdForecast.id = UUID()
            cdForecast.date = dateFormatter.date(from: forecast.date) ?? Date()
            cdForecast.dayWeather = forecast.dayweather
            cdForecast.nightWeather = forecast.nightweather
            cdForecast.dayTemp = Double(forecast.daytemp) ?? 0
            cdForecast.nightTemp = Double(forecast.nighttemp) ?? 0
            cdForecast.dayWind = forecast.daywind
            cdForecast.nightWind = forecast.nightwind
            cdForecast.city = city
            // 添加到城市的预报集合
            if city.forecasts == nil {
                city.forecasts = NSSet(object: cdForecast)
            } else {
                city.forecasts = city.forecasts?.adding(cdForecast) as? NSSet
            }
        }
    }
    
    // 保存上下文
    private func saveContext(_ context: NSManagedObjectContext) {
        do {
            try context.save()
            print("✅ [CoreData] 数据已成功保存到本地数据库")
        } catch {
            print("❌ [CoreData] 保存到本地数据库失败 - \(error)")
        }
    }
}

extension WeatherDataStorage {
    // 获取所有保存的城市
    func fetchAllCities() -> [CityEntity] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<CityEntity> = CityEntity.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取城市列表失败: \(error)")
            return []
        }
    }
    
    // 删除指定城市
    func deleteCity(forName name: String) {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<CityEntity> = CityEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        do {
            let cities = try context.fetch(request)
            cities.forEach { context.delete($0) }
            try context.save()
        } catch {
            print("删除城市失败: \(error)")
        }
    }
}
