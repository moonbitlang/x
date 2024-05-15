# MoonBit Experimental

This repository contains a module `moonbitlang/experimental`, which is an experimental 
library consisting of multiple packages that are subject to frequent changes or are 
not yet mature. These packages are initially placed here for testing and development.

As packages become stable and depending on the actual situation and community feedback, 
they may be merged into the standard library [moonbitlang/core](https://github.com/moonbitlang/core).

## Usage

To use a package from this repository, add module `moonbitlang/experimental` to 
dependencies by command

```
moon add moonbitlang/experimental 
``` 

And import any packages in your `moon.pkg.json` file. for example:

```json
{
  "import": [
    "moonbitlang/experimental/json5"
  ]
}
```

**Please note that the packages in this repository may change frequently.**

# Contributing

We welcome contributions! If you find a bug or have a suggestion, please open an issue. 
If you'd like to contribute code, please check the [contribution guide](https://github.com/moonbitlang/core/blob/main/CONTRIBUTING.md).

