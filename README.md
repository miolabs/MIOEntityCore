# MIOEntityCore

Keep track of a batch of objects: which ones you have, and what type each one is.

## Overview

`MIOEntityCore` gives you two small in-memory indexes, both keyed by a type name and a UUID, for the
questions that come up every time you work through a batch: what is in it, and do I already have this
particular one. Both understand that one type can be based on another, so you can store a `MenuItem`
and find it again by asking for a `Product`, which a plain dictionary cannot do. Neither one writes
anything anywhere, and what you put in is gone once you let go of it.

Which one you want depends on the question you are answering. `MECEntityCache` sorts a mixed batch
into groups, so you can act on it one type at a time rather than one object at a time. `MECCache`
holds several sets at once and answers "is this one in that set", keeping a version number per
object. They share no code, and there is one difference worth knowing before you start: storing
something you already hold replaces it in `MECEntityCache` and is ignored by `MECCache`.
