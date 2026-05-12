//
//  Default.swift
//  Nuwa
//
//  Created by 李招利 on 2026/5/8.
//

import Foundation
import Accessibility

@propertyWrapper
public struct Default<T: Codable>: RawRepresentable {
    public typealias RawValue = T
    
    @usableFromInline
    internal var _value: T
    
    @inlinable
    @inline(__always)
    public var rawValue: T {
        _read {
            yield _value
        }
    }
    
    @inlinable
    @inline(__always)
    public var wrappedValue: T {
        _read {
            yield _value
        }
        _modify {
            yield &_value
        }
        set {
            _value = newValue
        }
    }
    
    public init(rawValue: T) {
        _value = rawValue
    }
    
    
}
