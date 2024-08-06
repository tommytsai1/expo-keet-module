import ExpoModulesCore
import WebKit

public class ExpoKeetModule: Module {
    public func definition() -> ModuleDefinition {
        Name("ExpoKeetModule")
        
        View(ExpoKeetModuleView.self) {
          Events("onLoad")
            Prop("url") { (view, url: URL) in
              if view.webView.url != url {
                let urlRequest = URLRequest(url: url)
                view.webView.load(urlRequest)
              }
            }
         }
        
        Function("set") { (urlString: String, props: [String: Any], useWebKit: Bool, promise: Promise) in
            guard let url = URL(string: urlString) else {
                promise.reject("Invalid URL", "The URL provided is not valid.")
                return
            }
            
            let cookie: HTTPCookie
            do {
                cookie = try self.makeHTTPCookieObject(url: url, props: props)
            } catch {
                promise.reject("Cookie Creation Failed", error.localizedDescription)
                return
            }
            
            if useWebKit {
                if #available(iOS 11.0, *) {
                    DispatchQueue.main.async {
                        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
                        cookieStore.setCookie(cookie) {
                            promise.resolve(true)
                        }
                    }
                } else {
                    promise.reject("Not Available", "WebKit/WebKit-Components are only available with iOS 11 and higher!")
                }
            } else {
                HTTPCookieStorage.shared.setCookie(cookie)
                promise.resolve(true)
            }
        }
        
        Function("setFromResponse") { (urlString: String, cookie: String, promise: Promise) in
            guard let url = URL(string: urlString) else {
                promise.reject("Invalid URL", "The URL provided is not valid.")
                return
            }
            
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": cookie], for: url)
            HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
            promise.resolve(true)
        }
        
        Function("getFromResponse") { (urlString: String, promise: Promise) in
            guard let url = URL(string: urlString) else {
                promise.reject("Invalid URL", "The URL provided is not valid.")
                return
            }
            
            let request = URLRequest(url: url)
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise.reject("Request Failed", error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      let url = response?.url else {
                    promise.reject("Invalid Response", "The response is not valid.")
                    return
                }
                
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
                var cookieDict = [String: String]()
                
                for cookie in cookies {
                    cookieDict[cookie.name] = cookie.value
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                promise.resolve(cookieDict)
            }
            dataTask.resume()
        }
        
        Function("get") { (urlString: String, useWebKit: Bool, promise: Promise) in
            guard let url = URL(string: urlString) else {
                promise.reject("Invalid URL", "The URL provided is not valid.")
                return
            }
            
            if useWebKit {
                if #available(iOS 11.0, *) {
                    DispatchQueue.main.async {
                        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
                        cookieStore.getAllCookies { cookies in
                            var cookieDict = [String: Any]()
                            for cookie in cookies {
                                if url.host?.contains(cookie.domain) == true || cookie.domain == url.host {
                                    cookieDict[cookie.name] = self.createCookieData(cookie: cookie)
                                }
                            }
                            promise.resolve(cookieDict)
                        }
                    }
                } else {
                    promise.reject("Not Available", "WebKit/WebKit-Components are only available with iOS 11 and higher!")
                }
            } else {
                var cookieDict = [String: Any]()
                for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
                    cookieDict[cookie.name] = self.createCookieData(cookie: cookie)
                }
                promise.resolve(cookieDict)
            }
        }
        
        Function("clearByName") { (urlString: String, name: String, useWebKit: Bool, promise: Promise) in
            guard let url = URL(string: urlString) else {
                promise.reject("Invalid URL", "The URL provided is not valid.")
                return
            }
            
            if useWebKit {
                if #available(iOS 11.0, *) {
                    DispatchQueue.main.async {
                        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
                        cookieStore.getAllCookies { cookies in
                            var foundCookies = false
                            for cookie in cookies {
                                if cookie.name == name && self.isMatchingDomain(originDomain: url.host ?? "", cookieDomain: cookie.domain) {
                                    cookieStore.delete(cookie)
                                    foundCookies = true
                                }
                            }
                            promise.resolve(foundCookies)
                        }
                    }
                } else {
                    promise.reject("Not Available", "WebKit/WebKit-Components are only available with iOS 11 and higher!")
                }
            } else {
                let cookieStorage = HTTPCookieStorage.shared
                var foundCookies = false
                for cookie in cookieStorage.cookies ?? [] {
                    if cookie.name == name && self.isMatchingDomain(originDomain: url.host ?? "", cookieDomain: cookie.domain) {
                        cookieStorage.deleteCookie(cookie)
                        foundCookies = true
                    }
                }
                promise.resolve(foundCookies)
            }
        }
        
        AsyncFunction("getAll") { (useWebKit: Bool, promise: Promise) in
            if useWebKit {
                if #available(iOS 11.0, *) {
                    DispatchQueue.main.async {
                        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
                        cookieStore.getAllCookies { cookies in
                            promise.resolve(self.createCookieList(cookies: cookies))
                        }
                    }
                } else {
                    promise.reject("Not Available", "WebKit/WebKit-Components are only available with iOS 11 and higher!")
                }
            } else {
                let cookieStorage = HTTPCookieStorage.shared
                promise.resolve(self.createCookieList(cookies: cookieStorage.cookies ?? []))
            }
        }
    }
    
    private func makeHTTPCookieObject(url: URL, props: [String: Any]) throws -> HTTPCookie {
        guard let topLevelDomain = url.host else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: It may be missing a protocol (ex. http:// or https://)."])
        }
        
        var cookieProperties = [HTTPCookiePropertyKey: Any]()
        cookieProperties[.name] = props["name"]
        cookieProperties[.value] = props["value"]
        cookieProperties[.path] = props["path"] ?? "/"
        
        if let domain = props["domain"] as? String {
            var strippedDomain = domain
            if strippedDomain.hasPrefix(".") {
                strippedDomain.removeFirst()
            }
            
            if !topLevelDomain.contains(strippedDomain) && topLevelDomain != strippedDomain {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cookie URL host \(topLevelDomain) and domain \(domain) mismatched. The cookie won't set correctly."])
            }
            
            cookieProperties[.domain] = domain
        } else {
            cookieProperties[.domain] = topLevelDomain
        }
        
        cookieProperties[.version] = props["version"]
        cookieProperties[.expires] = props["expires"]
        if let secure = props["secure"] as? Bool, secure {
            cookieProperties[.secure] = secure
        }
        if let httpOnly = props["httpOnly"] as? Bool, httpOnly {
            cookieProperties[.init("HttpOnly")] = httpOnly
        }
        
        guard let cookie = HTTPCookie(properties: cookieProperties) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create HTTPCookie object."])
        }
        
        return cookie
    }
    
    private func createCookieData(cookie: HTTPCookie) -> [String: Any] {
        var cookieData = [String: Any]()
        cookieData["name"] = cookie.name
        cookieData["value"] = cookie.value
        cookieData["path"] = cookie.path
        cookieData["domain"] = cookie.domain
        cookieData["version"] = String(cookie.version)
        if let expiresDate = cookie.expiresDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            cookieData["expires"] = formatter.string(from: expiresDate)
        }
        cookieData["secure"] = cookie.isSecure
        cookieData["httpOnly"] = cookie.isHTTPOnly
        return cookieData
    }
    
    private func createCookieList(cookies: [HTTPCookie]) -> [[String: Any]] {
        return cookies.map { self.createCookieData(cookie: $0) }
    }
    
    private func isMatchingDomain(originDomain: String, cookieDomain: String) -> Bool {
        if originDomain == cookieDomain {
            return true
        }
        let parentDomain = cookieDomain.hasPrefix(".") ? cookieDomain : "." + cookieDomain
        return originDomain.hasSuffix(parentDomain)
    }

}