---
title: "Exercise: Catch and report setUp errors"
date: 2025-05-16T06:00:23+06:00
author:
  name: Andrea Bissoli
  # image: /images/author/avatar.png
hero: /images/tdd-exercise-1-hero.png
description: "A step-by-step article to implement Catch and report setUp errors exercise"
theme: Toha

menu:
  sidebar:
    name: "Exercise: Catch and report setUp errors"
    identifier: exercise-1
    parent: test-driven-development
    weight: 800
---
{{< alert type="warning" >}}
To gain a better understanding of the context, begin by reading the contents of the [xUnit/ch18](https://github.com/Sk3pper/test-driven-development-by-example/tree/main/xUnit) directory, where you will find the relevant code and tests that illustrate the concepts discussed in this chapter.
{{< /alert >}}

# Exercise: Catch and report setUp errors
Implement the task: **Catch and report setUp errors**. There is a subtlety hidden inside this method. 
```python
def run(self):
      result = TestResult()
      result.testStarted()
      self.setUp()

      try:
          method = getattr(self, self.name)
          method()
      except:
          result.testFailed()

      self.tearDown()
      return result
```

The way it is written, if a disaster happens during **setUp(),** then the exception won't be caught. That can't be what we mean - we want our tests to run independently of one another. I'll leave that next test and its implementation as an exercise for you (sore fingers, again).

Make in practice what we learn so far.

# Step 0: Add print results
Before starting with the first step, we need to address a major issue. When an assertion fails, the error is not shown because all exceptions are being caught silently. Let me show you an example. If we change the testResult assertion from `assert("1 run, 0 failed" == result.summary())` to `assert("0 run, 0 failed" == result.summary())` with the current code in place, we don’t see any error message or indication that something went wrong. To fix this and make failures visible, we can add the following line to our test code:

```python
result = TestCaseTest("testTemplateMethod").run()
print("testTemplateMethod: \t\t{result}".format(result=result.summary()))

result = TestCaseTest("testResult").run()
print("testResult: \t\t\t{result}".format(result=result.summary()))

result = TestCaseTest("testFailedResultFormatting").run()
print("testFailedResultFormatting: \t{result}".format(result=result.summary()))

result = TestCaseTest("testFailedResult").run()
print("testFailedResult: \t\t{result}".format(result=result.summary()))
```
With this change we can see that now the `testResult` is broken
```bash
testTemplateMethod: 		1 run, 0 failed
testResult: 			    1 run, 1 failed
testFailedResultFormatting: 1 run, 0 failed
testFailedResult: 		    1 run, 0 failed
```
Roll back to `assert("1 run, 0 failed" == result.summary())` and we have:
```bash
testTemplateMethod: 		1 run, 0 failed
testResult: 			    1 run, 0 failed
testFailedResultFormatting: 1 run, 0 failed
testFailedResult: 		    1 run, 0 failed
```
**Lesson learned:** the `assert` works but it does not tell us any hint about where the test code is failed.

I will propose three solutions.
1. The first one handles errors in the `setUp` method by checking the `WasRun` log. 
2. The second solution explicitly manages the case where the `setUp` method raises an exception. 
3. The third solution catches the raised exception and reports it.

# Solution 1
## Step1: Add a little test.
We write a test with a broken setUp method. To do this, we create a fake `WasRun` object where the `setUp` method is intentionally broken. When this method is called, it adds `"Error setUp"` to the log.
```python
def testSetUpError(self):
    test = BrokenSetUpWasRun("testMethod") 
    test.run()
    assert("Error setUp testMethod tearDown " == test.log)
```

## Step2: Run all tests and fail.
We run the tests and get the following output:
```bash
testTemplateMethod: 		1 run, 0 failed
testResult: 			    1 run, 0 failed
testFailedResultFormatting: 1 run, 0 failed
testFailedResult: 		    1 run, 0 failed
testSetUpError: 		    1 run, 1 failed
```

In this situation, we don't get much information about where the `testSetUpError` test is failing. However, we can guess that the root of the problem is the missing `BrokenSetUpWasRun` object.

For now, we can add a simple print statement in the run method of the `TestCase` class to help us confirm what's going on.

```python
try:
    method = getattr(self, self.name)
    method()
except Exception as e:
    if e.args: print(e)
    result.testFailed()
```

We will see the following message printed:

```bash
name 'BrokenSetUpWasRun' is not defined
testSetUpError: 		1 run, 1 failed
```

## Step3: Make a change.
Now we can add the `BrokenSetUpWasRun` class. As you can see, the `setUp` log message is different, and an "Error" string has been added to indicate the failure.

```python
class BrokenSetUpWasRun(WasRun):
    def setUp(self):
        self.log = "Error setUp "
```

## Step4: Run the tests and succeed.
We run the tests and get the following output:
```bash
testTemplateMethod: 		1 run, 0 failed
testResult: 			    1 run, 0 failed
testFailedResultFormatting: 1 run, 0 failed
testFailedResult: 		    1 run, 0 failed
testSetUpError: 		    1 run, 0 failed
```

## Step5: Refactor to remove duplication.
No needed.

# Solution 2
## Step1: Add a little test.
In this case, the test is a bit different. We still use the same `BrokenSetUpWasRun` class, but this time we expect a failure message (not just something written in the log).

```python
def testSetUpError(self):
    test = BrokenSetUpWasRun("testMethod") 
    result = test.run()
    assert("1 run, 1 failed" == result.summary())
```

## Step2: Run all tests and fail.
```bash
testTemplateMethod: 		1 run, 0 failed
testResult: 			    1 run, 0 failed
testFailedResultFormatting: 1 run, 0 failed
testFailedResult: 		    1 run, 0 failed
testSetUpError: 		    1 run, 1 failed
```
## Step3: Make a change
Add raise Exception in `setUp` method in `BrokenSetUpWasRun` class.

```python
class BrokenSetUpWasRun(WasRun):
    def setUp(self):
        raise Exception
```

We modify the code to catch the exception when the `setUp` method is called.

**TestCase**
```python
try:
    self.setUp()
    method = getattr(self, self.name)
    method()
except Exception as e:
    if e.args: print(e)
    result.testFailed()
```

## Step4: Run the tests and succeed.
On the first run, we get the following error: `'BrokenSetUpWasRun' object has no attribute 'log'`. This happens because the log attribute is missing in the BrokenSetUpWasRun object. We need to initialize the log inside this class.

```python
class WasRun(TestCase):
    def __init__(self, name):
        self.log = ""
        TestCase.__init__(self, name=name)
```
Now everything is ok:
```bash
testTemplateMethod: 		1 run, 0 failed
testResult: 			    1 run, 0 failed
testFailedResultFormatting: 1 run, 0 failed
testFailedResult: 		    1 run, 0 failed
testSetUpError: 		    1 run, 0 failed
```
## Step5: Refactor to remove duplication.
No needed

# Solution 3
In this solution, we want to report the setUp error explicitly. To do this, we add the setUp status to the test report.

## Step1: Add a little test.
```python
def testSetUpError(self):
    test = BrokenSetUpWasRun("testMethod") 
    result = test.run()
    assert("1 run, 1 failed (setUp: ERROR)" == result.summary())
    return result
```
## Step2: Run all tests and fail.
```bash
testTemplateMethod: 		1 run, 0 failed
testResult: 			    1 run, 0 failed
testFailedResultFormatting: 1 run, 0 failed
testFailedResult: 		    1 run, 0 failed
testSetUpError: 		    1 run, 1 failed
```
## Step3: Make a change
We have the same BrokenSetUpWasRun class
```python
class BrokenSetUpWasRun(WasRun):      
    def setUp(self):
        raise Exception
```
But in this case it is necessary to make a change to the `TestResult` class adding `setUpError` attribute, `testHaveSetUpError` method and editing the `summary` method.

**TestResult**
```python
def __init__(self):
    self.runCount = 0
    self.errorCount = 0
    self.setUpError = False
    
def testHaveSetUpError(self):
    self.setUpError = True

def summary(self):
    setUpStatus = "ERROR" if self.setUpError else "OK"
    return "%d run, %d failed (setUp: %s)" % (self.runCount, self.errorCount, setUpStatus)
```

We also need to change how errors are handled when `setUp` is called. The method `testHaveSetUpError()` is used to set the `setUpError` flag to `True`, and `testFailed` is called to notify that an error occurred during the test.

```python
try:
    self.setUp()
except Exception as e:
    if e.args: print(e)
    result.testHaveSetUpError()
    result.testFailed()

try:
    method = getattr(self, self.name)
    method()
except Exception as e:
    if e.args: print(e)
    result.testFailed()
```

We also change the asserts in other tests:

```python    
def testResult(self):
    test = WasRun("testMethod") 
    result = test.run()
    assert("1 run, 0 failed (setUp: OK)" == result.summary())
    
def testFailedResult(self):
    test = WasRun("testBrokenMethod") 
    result = test.run()
    assert("1 run, 1 failed (setUp: OK)" == result.summary())
    
def testFailedResultFormatting(self):
    result = TestResult()
    result.testStarted()
    result.testFailed()
    assert("1 run, 1 failed (setUp: OK)" == result.summary())
```
## Step4: Run the tests and succeed.
```bash
    testTemplateMethod: 		1 run, 0 failed (setUp: OK)
    testResult: 			    1 run, 0 failed (setUp: OK)
    testFailedResultFormatting: 1 run, 0 failed (setUp: OK)
    testFailedResult: 		    1 run, 0 failed (setUp: OK)
    testSetUpError: 		    1 run, 0 failed (setUp: OK)
```
## Step5: Refactor to remove duplication.
No needed

# Considerations
I’m not sure which solution is the best — Solution 1, Solution 2, or Solution 3. However, I believe the last one is the best because it meets all the requirements: **catching and reporting setUp errors**. It properly catches any exceptions raised by the setUp method and carefully reports them in the summary.

Open questions:
- If `setUp() fails, does it still make sense to call `self.tearDown()`?