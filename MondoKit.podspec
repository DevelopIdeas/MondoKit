Pod::Spec.new do |spec|
spec.name = "MondoKit"
spec.version = "0.2.1"
spec.summary = "MondoKit is a Swift framework wrapping the Mondo API at https://getmondo.co.uk/docs/"
spec.homepage = "https://github.com/pollarm/MondoKit"
spec.license = { type: 'MIT', file: 'LICENSE' }
spec.authors = { "Mike Pollard" => 'mikeypollard@me.com' }
spec.social_media_url = "http://twitter.com/mikeypollard1"

spec.platform = :ios, "9.0"
spec.requires_arc = true
spec.source = { git: "https://github.com/DevelopIdeas/MondoKit.git", tag: spec.version }
spec.source_files = "MondoKit/**/*.{h,swift}"

spec.dependency 'SwiftyJSON', '~> 3.0'
spec.dependency "SwiftyJSONDecodable", :git => 'https://github.com/DevelopIdeas/SwiftyJSONDecodable.git'
spec.dependency "Alamofire"
spec.dependency "KeychainAccess"

end
