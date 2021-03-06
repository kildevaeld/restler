# Restler

[![CI Status](http://img.shields.io/travis/Softshag & Me/Restler.svg?style=flat)](https://travis-ci.org/Softshag & Me/Restler)
[![Version](https://img.shields.io/cocoapods/v/Restler.svg?style=flat)](http://cocoapods.org/pods/Restler)
[![License](https://img.shields.io/cocoapods/l/Restler.svg?style=flat)](http://cocoapods.org/pods/Restler)
[![Platform](https://img.shields.io/cocoapods/p/Restler.svg?style=flat)](http://cocoapods.org/pods/Restler)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

```swift

class Blog {
  var title: String
  var body: String
}

let blogDescription = ResponseDescription<Blog> { (value) throws -> Blog  in 
  
  let blog = Blog()
  
  blog.title = value["title"].stringValue
  blog.body = value["body"].stringValue
  
  return blog
  
}

let restler = Restler("http://example.com")

restler.resource("/blog", descriptor: blogDescription)
.paginate()
.all().then { result in 
  print("result: \(result)")
}


```

## Requirements

## Installation

Restler is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Restler"
```

## Author

Softshag & Me, admin@softshag.dk

## License

Restler is available under the MIT license. See the LICENSE file for more info.
