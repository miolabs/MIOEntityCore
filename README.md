# MIOEntityCore

Describe your entities, render their values, and keep track of a batch of them.

## Overview

An entity carries its attributes and relationships, so a value can be rendered without also holding
the model it came from. `MECAttributeType` renders one value to JSON and `MECPolicy` decides how;
the `MIOEntityCoreDB` target does the same for SQL, picking the storage from the type the model
declares rather than from the Swift value in hand. It is a separate target so that an app can depend
on `MIOEntityCore` without acquiring MIODB.

Two small in-memory indexes come with it, both keyed by a type name and a UUID, for working through a
batch. `MECEntityCache` sorts a mixed batch into groups; `MECCache` holds several sets at once and
answers "is this one in that set", keeping a version number per object. Both understand that one type
can be based on another, so a `MenuItem` can be found by asking for a `Product`. One difference worth
knowing before you start: storing something you already hold replaces it in `MECEntityCache` and is
ignored by `MECCache`.
