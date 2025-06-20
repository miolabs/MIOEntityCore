//
//  Functions.swift
//  MIOEntityCore
//
//  Created by Javier Segura Perez on 15/9/24.
//

#if os(WASI)

import Foundation

let _cache = MECEntityCache<[String:Any]>()

@_expose(wasm, "MECInsert")
@_cdecl("MECInsert")
public func MECInsert ( _ entityName: String, _ uuid: UUID, _ entityBody: [String:Any] ) {
    _cache.insert( entityName, uuid, entityBody )
    print("MECInsert DONE!")
}

#endif

