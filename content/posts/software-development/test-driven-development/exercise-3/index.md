---
title: "Exercise: Create TestSuite from a TestCase class"
date: 2025-05-20T06:00:23+06:00
author:
  name: Andrea Bissoli
  # image: /images/author/avatar.png
hero: /images/tdd-exercise-3-hero.png
description: "A step-by-step article to implement Create TestSuite from a TestCase class exercise"
theme: Toha

menu:
  sidebar:
    name: "Exercise: Create TestSuite from a TestCase class"
    identifier: exercise-3
    parent: test-driven-development
    weight: 800
---
{{<alert type="warning">}}
To gain a better understanding of the context, begin by reading the contents of the [xUnit/ch18](https://github.com/Sk3pper/test-driven-development-by-example/tree/main/xUnit) directory, where you will find the relevant code and tests that illustrate the concepts discussed in this chapter.
{{</alert>}}

{{<alert type="info">}}
It is possible to find all the source code of this exercise [here](https://github.com/Sk3pper/test-driven-development-by-example/tree/main/xUnit/ch23_exerciseB).
{{</alert>}}

# Exercise: 
The last task to complete is creating a **Create TestSuite from a TestCase class** — that is, constructing a suite automatically from a test class.

## Epoch 1
### Step1: Add a little test.
The first step is often the hardest for those approaching the TDD style. As Kent Beck writes in the book, **we have to imagine the perfect interface** — even if it doesn't exist yet — for the operation we're about to implement. We're telling ourselves a **story** about how the operation will look from the outside.

We image a TestSuite constructor takes in input the TestCase class.

```python
def testSuiteFromTestCase(self):
    suite = TestSuite(TestCaseTest)
    suite.run(self.result)
    assert("7 run, 0 failed" == self.result.summary())
```

### Step2: Run all tests and fail
When we run all the tests, Python tells us: `TestSuite.__init__() takes 1 positional argument but 2 were given`. This means that the TestSuite constructor doesn't yet handle a TestCase class name as an input argument. To fix this, we can modify the constructor to accept the class name as a parameter:
```python
def __init__(self, testCase):
    self.tests = []
    self.testCase = testCase
```
With this change in place, we’ve broken the `testSuite` test, since we're no longer passing the TestCase class name to the constructor.

### Step3: Make changes and run tests
I don't like the code in its current form. I prefer to keep the constructor clean, so we apply a small change instead.

```python
def __init__(self, testCaseClass=None):
    self.tests = []
    self.testCaseClass = testCaseClass

    if testCaseClass:
        self.testCaseClass = testCaseClass
```
With this change, we can choose whether or not to pass the `testCaseClass` as an input argument.
When it is provided, we can parse the class and extract all the tests to add to the suite.
The idea is that, given a test case class, we look for all methods whose names start with the word `'test'`.

```python
def loadTestsFromTestCase(self, testCaseClass):
    self.testCaseClass = testCaseClass
    
    test_methods = [method for method in dir(self.testCaseClass) 
                    if method.startswith('test') and callable(getattr(self.testCaseClass, method))]

    for method_name in test_methods:
        test_instance = self.testCaseClass(method_name)
        self.add(test_instance)
```

The output is the following:
```bash
testTemplateMethod: 			    1 run, 0 failed
testResult: 				        1 run, 0 failed
testFailedResultFormatting: 		1 run, 0 failed
testFailedResult: 			        1 run, 0 failed
testSetUpError: 			        1 run, 0 failed
testTearDownWithTestMethodError: 	1 run, 0 failed
testSuite: 				            1 run, 0 failed
maximum recursion depth exceeded
testSuiteFromTestCase: 			    1 run, 1 failed
```
The problem is that the test `testSuiteFromTestCase` is being called recursively. To fix this, we need to rename it to `suiteFromTestCaseTest`.

### Step4: Run the tests and succeed
Running the tests:
```python
suite = TestSuite()

suite.add(TestCaseTest("testTemplateMethod"))
suite.add(TestCaseTest("testResult"))
suite.add(TestCaseTest("testFailedResultFormatting"))
suite.add(TestCaseTest("testFailedResult"))
suite.add(TestCaseTest("testSetUpError"))
suite.add(TestCaseTest("testTearDownWithTestMethodError"))
suite.add(TestCaseTest("testSuite"))
suite.add(TestCaseTest("suiteFromTestCaseTest"))

result = TestResult()
suite.run(result=result)

print(result.summary())
```
We have the following output:
```bash
8 run, 0 failed
```
Now we can update the code that executes the test to utilize the `TestSuite`.

```python
suite = TestSuite(TestCaseTest)
result = TestResult()
suite.run(result=result)
print(result.summary())
```

Remember that to test the new test case, it must be added separately.

```python
suite = TestSuite(TestCaseTest)
result = TestResult()
suite.add(TestCaseTest("suiteFromTestCaseTest"))
suite.run(result=result)
print(result.summary())
```

## Epoch 2
I’m not comfortable with adding `suiteFromTestCaseTest` separately; I would prefer to find a better approach.

### Step1: Add a little test.
Renaming it to `testSuiteFromTestCase` brings back the recursion issue.

### Step2: Run all tests and fail

```python
if __name__ == "__main__":
    suite = TestSuite(TestCaseTest)
    result = TestResult()
    suite.run(result=result)
    print(result.summary())
```

```bash
maximum recursion depth exceeded
8 run, 1 failed
```

### Step3: Make a change
The problem we face with the `loadTestsFromTestCase` method is that it automatically adds all methods starting with `"test"` from a given `TestCase` class. This creates a potential infinite recursion when we have a test method that itself creates a `TestSuite` from the same `TestCase` class.

The key insight is that rather than implementing complex recursion detection logic, we can solve this problem through better design of our test structure.
By creating a dedicated `SampleTestCaseForSuiteTest` class that serves as a simple, controlled test fixture, we achieve separation of concerns. This dedicated test class contains only the methods needed to verify the `TestSuite` functionality, without any methods that would trigger the creation of another `TestSuite` from the original test class. This is a clean approach that doesn't require any complex tracking mechanisms, global variables, or recursion detection algorithms. 

```python
class SampleTestCaseForSuiteTest(TestCase):
    pass
```

The test now is the following
```python
def testSuiteFromTestCase(self):
    suite = TestSuite(SampleTestCaseForSuiteTest)
    suite.run(self.result)
    assert("0 run, 0 failed" == self.result.summary())
```

### Step4: Run the tests and succeed
Running the TestSuite by passing TestCaseTest as an argument.
```python
suite = TestSuite(TestCaseTest)
result = TestResult()
suite.run(result=result)
print(result.summary())
```

we have
```bash
8 run, 0 failed
```