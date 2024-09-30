# LoopAlgorithm

![Platform](https://img.shields.io/badge/platforms-iOS%2015.0%20%7C%20macOS%2013.0%20%7C%20tvOS%2015.0%20%7C%20watchOS%208.0-F28D00.svg)

LoopAlgorithm predicts future blood glucose from insulin, carb, and historic glucose data, and generates dosing recommendations. 

Please understand that this project:

* Is highly experimental
* Is not approved for therapy

## Command Line Runner

There is a command line utility that will run the algorithm with a scenario input file:

```
swift build
./.build/debug/LoopAlgorithmRunner Tests/LoopAlgorithmTests/Fixtures/suspend_scenario.json > output.json
```
