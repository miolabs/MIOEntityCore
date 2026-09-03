# ``MIOEntityCore``

Describe your entities, render their values, and keep track of a batch of them.

## Overview

The package does two jobs. One describes what your objects
look like and turns their values into JSON. The other keeps track of a batch of objects in memory:
which ones you have, and what type each one is.

Both halves talk about entities, ids and bodies. An **entity** is a type name, like `Product`. An
**id** is the UUID identifying one particular object. A **body** is whatever you keep alongside it: a
database row, a decoded payload, or just `true` when all you want is a list of ids.

## The entity

### Describing an entity

An entity carries more than a name. Attributes and relationships come with it, which is what lets a
value be rendered without also holding the model it came from.

```swift
let folder = MECEntity( name: "Folder",
                        attributes: [ MECAttribute( name: "identifier", type: .uuid ),
                                      MECAttribute( name: "title", type: .string ),
                                      MECAttribute( name: "count", type: .integer64,
                                                    defaultValueString: "0" ) ],
                        relationships: [ MECRelationship( name: "todos",
                                                          destinationEntityName: "Todo",
                                                          inverseName: "folder",
                                                          isToMany: true ) ] )
```

A relationship names its destination rather than holding it. Inverses are cyclic by definition, so
references would mean a retain cycle or an `unowned` and the crash after it. Resolve one with
``MECModel/entity(named:)``.

A default is text, the way a model file records it. `"1"` is a valid default for both a boolean and
an integer, and only the declared type says which; ``MECAttributeType/value(fromDefaultText:)`` reads
it back.

Inherited attributes are not merged in. An entity lists its own, and walking
``MECEntity/superEntity`` is the caller's job, because a flattened set means different things in
different contexts.

### Building a model from a list of names

A model with two or three entities is fine to write out by hand. A real one has dozens, and you
build one every pass, so it is worth wrapping up once.

Nothing here ships with the package. Your types are yours to describe, so this is an extension you
write in your own project:

```swift
extension MECModel
{
    /// Builds a model from a name-to-parent description of your types.
    convenience init ( _ hierarchy: [String: String?], abstract: Set<String> = [] ) {
        var built: [String: MECEntity] = [:]

        // A parent has to exist before the child that names it, so each one is
        // made on demand and the recursion takes care of the order.
        func make ( _ name: String ) -> MECEntity {
            if let already = built[ name ] { return already }

            let parent = hierarchy[ name ].flatMap { $0 }.map { make( $0 ) }
            let entity = MECEntity( name: name,
                                    isAbstract: abstract.contains( name ),
                                    superEntity: parent )
            built[ name ] = entity
            return entity
        }

        for name in hierarchy.keys { _ = make( name ) }
        self.init( entities: Array( built.values ) )
    }
}
```

The ordering is the part to keep whatever shape you give this. A ``MECEntity`` takes its parent at
`init` and cannot be changed afterwards, so a hierarchy is built from the roots down. Making each
entity on demand is one way to get that for free.

Building a model is then one line, and a name that only ever appears as a parent still gets created:

```swift
let model = MECModel( [ "MenuItem": "Product", "Combo": "MenuItem" ] )

model.entity( named: "Product" )        // exists, even though it was never a key
```

Mark abstract types as you go, with `MECModel( hierarchy, abstract: [ "Document" ] )`. It changes what
you are able to look up later, which the next section covers.

Keep the model and reuse it. ``MECCache`` does not hold on to it for you: you pass entity values in on
every call, so it is on you to keep handing it entities from the same model.

### Rendering values

``MECAttributeType`` renders one value, and ``MECPolicy`` decides how.

```swift
let price = MECAttribute( name: "price", type: .decimal, isOptional: true )
let note  = MECAttribute( name: "note", type: .string, isOptional: true )

try price.jsonValue( from: Decimal( string: "1.50" )! )   // "1.5", a string
try note.jsonValue( from: nil )                           // NSNull
```

The order is the model's own: an absent value falls back to the default, and only an absent value
with no default on a required attribute is an error. An absent optional renders as `NSNull`, and
``MECPolicy/includeNulls`` decides whether the key survives into the payload.

``MECPolicy`` holds the choices that change what a client sees, so none of them are hard-coded:
uppercase UUIDs, decimals as strings so a reader cannot quietly turn money into a `Double`, ISO 8601
dates with fractional seconds because dropping them reorders records written in the same second.

Every switch over ``MECAttributeType`` is written without a `default:`. Adding a case breaks the
build everywhere a decision is needed, rather than falling through to something plausible.

## Keeping track of a batch

Say a batch of changes arrives and you have to apply it. Some are products, some are orders, some are
order lines, all mixed together. Before you can do anything useful you keep needing the same two
answers:

- **What is in this batch?** You would rather handle all the products at once than go one at a time.
- **Do I already have this particular one?** So you can tell something new from something you are
  updating.

`MIOEntityCore` gives you two small helpers for exactly that. You put things in, then ask questions
about what you put in.

Both helpers live entirely in memory. Nothing is written anywhere, and everything you put in is gone
once you let go of the helper. The examples below use database rows as bodies, but any type will do.

The useful part is that they understand your **type hierarchy**. If a `MenuItem` is a kind of
`Product`, you can store a `MenuItem` and later find it by asking for a `Product`. A plain dictionary
cannot do that for you.

> Important: Neither one is safe to use from several threads at once. Use one from a single thread, or
> add your own locking around it.

### Which one do I use?

Pick by the question you need answered.

**Use ``MECEntityCache`` to sort a batch into groups.** You have a mixed pile and you want to handle
it one type at a time.

**Use ``MECCache`` to keep track of several piles at once.** You are comparing sets against each
other, asking "is this one in that pile?"

The two do not share anything. Storing something in one will **not** make it show up in the other, so
choose one for a given job and stay with it.

| | ``MECEntityCache`` | ``MECCache`` |
|---|---|---|
| Good for | sorting a batch into groups | comparing several sets against each other |
| You name types with | a `String` | a ``MECEntity`` you make first |
| Storing something you already have | replaces it with the new one | keeps the old one, ignores the new one |
| Keeps a version number | no | yes |

That third line is the one to watch, because the two behave in **opposite** ways.
``MECEntityCache`` takes the newer copy. ``MECCache`` keeps the first one and quietly discards what
you just handed it, on the assumption that you already have it. Changing a stored body in
``MECCache`` is what ``MECCache/update(entity:_:version:updateBlock:)`` is for.

Get that backwards and nothing crashes. You just keep reading old data, and that is hard to trace
back to its cause.

### Sorting a batch into groups

You have a mixed batch and want to handle each type in one go, instead of one at a time. That is
what ``MECEntityCache`` is for.

```swift
// A batch that arrived from somewhere: products, orders and order lines, all mixed together.
let changedRows: [Row] = loadChangedRows( )

let batch = MECEntityCache<Row>( )

for row in changedRows {
    batch.insert( row.entityName, row.id, row )   // "Product", the row's id, the row itself
}

// Now walk it one type at a time.
for typeName in batch.entities_name( ) {          // "Product", "Order", "OrderLine"
    let ids = batch.entity_ids( typeName )        // every id stored under that name

    // One trip to the database per type, rather than one per row.
    let rows = try db.fetch( table: typeName, ids: ids )
}
```

If the batch held 500 rows across 3 types, that is 3 queries instead of 500.

`Row` there is just a type from the example. Neither helper puts any requirement on what you store:
it does not have to conform to a protocol, and it can be as simple as a `Bool`. The `entityName` and
`id` in the loop come from the example's own type, not from the package.

Notice you get things back out under the same name you put them in under. That is the ordinary way to
use this one, and it is why ``MECEntityCache/init(_:)`` is usually called with no arguments: the type
hierarchy never comes up. You only need to describe your hierarchy if you intend to store a `MenuItem`
and then go looking for it as a `Product`, which "How the type hierarchy works" covers.

### Comparing several sets at once

The other helper is for a trickier situation. A batch of changes has arrived, and for each one you
need to work out whether it is new, an edit, or a deletion. That means holding **several sets at the same time** and asking which set
a given id is in. That is what ``MECCache`` is for.

```swift
let product = MECEntity( name: "Product" )
let model   = MECModel( entities: [ product ] )

let onFile   = MECCache<Row>( )    // rows the database already has
let incoming = MECCache<Row>( )    // rows this batch wants to change
let toDelete = MECCache<Bool>( )   // just a list of ids, nothing to store with them

// ... you fill those three in, from the database and from the batch ...

// Then, for any id, you can ask which sets it is in:
if incoming.contains( entity: product, id: rowID ) == false {
    // The batch does not mention it, so leave it alone.
}
else if onFile.contains( entity: product, id: rowID ) == false {
    // The batch mentions it but the database has never seen it, so it is new.
}
else {
    // Both know about it, so it is an edit.
}
```

`toDelete` there is a small trick worth knowing. The package has no separate "set" type, so when you
only care about *which ids are in the list* and have nothing to keep alongside them, use
`MECCache<Bool>` and store `true` as a placeholder body. You get a set that still understands your
type hierarchy.

### How the type hierarchy works

Both helpers know that a `MenuItem` is a kind of `Product`, so that storing one and asking for the
other works. They get there differently, and the difference shows up in which methods respect it.

**``MECCache`` files an object under every type it belongs to, the moment you store it.** Store a
`MenuItem` and it is filed under `MenuItem` *and* `Product` right away, so looking for a `Product`
finds it later.

Because looking up also walks upward, asking for a `MenuItem` finds something that was only ever
stored as a `Product`:

```swift
_ = cache.insert( entity: product, id: rowID, body: row )   // stored as a plain Product

cache.contains( entity: menuItem, id: rowID )   // true, even though it is not a MenuItem
cache.ids( fromEntityName: "MenuItem" )         // empty: nothing was stored as a MenuItem
```

So read ``MECCache/contains(entity:id:)`` as "have I got this id, at this type **or anything above
it**". When you want a straight answer about one exact type, use ``MECCache/ids(fromEntityName:)``.

**``MECEntityCache`` does the opposite: it files an object under one name only, and works the
hierarchy out when you ask.** For that it needs you to describe the hierarchy up front:

```swift
let cache = MECEntityCache<Row>( [ "MenuItem": [ "Product" ] ] )
cache.insert( "MenuItem", rowID, row )

cache.contains( "Product", rowID )   // true
```

Two things to watch:

**Write out every ancestor, not just the immediate parent.** If a `Refund` is a `Ticket` and a
`Ticket` is a `Document`, write `[ "Refund": [ "Ticket", "Document" ] ]`. Listing only each type's
parent means asking for a `Document` will not find your `Refund`.

**The hierarchy applies when you look something up, and nowhere else.** Asking with
``MECEntityCache/contains(_:_:)-(String,UUID)`` or ``MECEntityCache/value(_:_:)`` will search the
parent types you listed. Everything else, including ``MECEntityCache/diff_ids(_:_:)``,
``MECEntityCache/entity_ids(_:)`` and ``MECEntityCache/remove(_:_:)``, only ever looks at the exact
name you pass. In practice that means:

```swift
let cache = MECEntityCache<Row>( [ "MenuItem": [ "Product" ] ] )
cache.insert( "MenuItem", rowID, row )

cache.contains( "Product", rowID )        // true, it searched MenuItem too
cache.diff_ids( "Product", [ rowID ] )    // [ rowID ], reported as one you are missing
cache.remove( "Product", rowID )          // does nothing, it is filed under MenuItem
```

So when you are relying on the hierarchy, stay with `contains` and `value`.

### Worth paying attention to

All of it is intended behaviour. It is here because none of it is guessable from the method names.

**An abstract type cannot be used to look things up.** Mark a type abstract and ``MECCache`` skips it
when filing, so searching by it comes up empty even though the object is right there. Use
`isAbstract: false` for anything you intend to search by. See ``MECEntity/init(name:isAbstract:superEntity:attributes:relationships:)``.

**Storing the same thing twice does opposite things** in the two helpers. Covered above, and repeated
here because it is the one that costs real time.

**Asking for a version does not filter anything.** ``MECCache/value(entity:id:version:)`` takes a
version number and then ignores it. You get the stored body back whatever you pass.

**Storing something hands you back a value you cannot read.**
``MECCache/insert(entity:id:body:version:)`` returns a ``MECCacheObject`` whose contents are private
to the package, and Swift warns you for not using a returned value. Write `_ = cache.insert( ... )`
when you only want it stored, and use ``MECCache/value(entity:id:version:)`` to read the body back.

**Type names hang around after their objects are gone.** ``MECCache/entitiesByName`` and
``MECEntityCache/entities_name()`` keep listing a name after you remove the last object under it. The methods that
return ids stay accurate, so use those when the difference matters.

**A bad id stops your program rather than returning nil.** Ids are taken as `Any`, and anything that
is not a `UUID` or a valid UUID string will crash. Check ids before handing them over.

**Removing by a parent type leaves a loose end.** In ``MECCache``, removing an object by one of its
parent types leaves the entry under its own type behind. ``MECCache/fetch(entity:id:)`` tidies that up by
itself next time it runs into it, so it is rarely something you notice.

## Topics

### Describing your types

A model, its entities, and what each entity is made of. ``MECCache`` needs the first two, because it
asks for a ``MECEntity`` rather than a name; the codecs need the rest. ``MECEntityCache`` takes plain
strings and uses none of it.

- ``MECModel``
- ``MECEntity``
- ``MECAttribute``
- ``MECRelationship``
- ``MECAttributeType``

### Rendering values

One value out, to JSON. ``MECPolicy`` carries the choices; ``MECError`` is what a refusal looks like.

- ``MECPolicy``
- ``MECError``

### Sorting a batch into groups

Stores objects under a type name, and hands them back grouped by that name.

- ``MECEntityCache``

### Comparing several sets against each other

Stores objects under a ``MECEntity``, keeps a version number for each, and can tell you which ids
from a list you are missing.

- ``MECCache``
- ``MECCacheObject``
- ``MECCacheObjectUpdateBlock``
