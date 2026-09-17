import Foundation

let data = try Data(contentsOf: URL(fileURLWithPath: "docs/app-store/en-US.json"))
let metadata = try JSONSerialization.jsonObject(with: data) as! [String: Any]
for (key, limit) in [("name", 30), ("subtitle", 30), ("promotional_text", 170), ("description", 4000), ("keywords", 100)] {
    let value = metadata[key] as! String
    precondition(!value.isEmpty && value.count <= limit, "Invalid \(key): \(value.count)/\(limit)")
}
precondition(metadata["one_time_base_price_usd"] as? String == "9.99")
for key in ["support_url", "privacy_policy_url", "marketing_url"] {
    let url = URL(string: metadata[key] as! String)!
    precondition(url.scheme == "https" && url.host == "github.com")
    precondition(url.path.hasPrefix("/helloimrizy-pages/jotwisp"))
}
print("Listing field lengths, intended public URLs, and US$9.99 price verified.")
