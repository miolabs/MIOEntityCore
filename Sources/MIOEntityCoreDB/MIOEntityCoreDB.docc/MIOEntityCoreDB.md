# ``MIOEntityCoreDB``

Render a value to SQL, using the type the model declares.

## Overview

One target, one job, and the reason it is separate from `MIOEntityCore` is the dependency: this is
the half that needs MIODB. Anything that only describes entities or renders JSON should depend on
`MIOEntityCore` and stop there, so an app does not acquire a query builder it will never call.

The difference from `MDBValue.init( _: Any? )` is the point of it. That initialiser picks a storage
case by looking at the Swift value in hand, so a decimal a driver returned as a `Double` is stored
and rendered as a double, and the type the model declared never gets a vote. Here the declared type
chooses and the value is read to fit it.

```swift
let price = MECAttribute( name: "price", type: .decimal )

try price.dbValue( from: Double( 1.5 ) ).value      // 1.5, stored as a decimal
try MDBValue( Double( 1.5 ) ).storage               // .double
```

Absence follows the model, in the same order as the JSON leg: an absent value falls back to the
default, and only an absent value with no default on a required attribute is an error. An absent
optional is SQL `NULL`.

Two types are refused rather than guessed at. A transformable needs its own value transformer, which
nothing here has been handed. Binary data has no `MDBValueStorage` case, and every encoding available
at this layer is wrong in a different way: base64 lands in a `bytea` column as characters, and a hex
literal is dialect-specific. Both throw, and say so.
