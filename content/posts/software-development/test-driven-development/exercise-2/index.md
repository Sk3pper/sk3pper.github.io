---
title: "Exercise: Invoke tearDown even if the test method fails"
date: 2025-05-20T06:00:23+06:00
author:
  name: Andrea Bissoli
  # image: /images/author/avatar.png
hero: /images/tdd-exercise-2-hero.png
description: "A step-by-step article to implement Invoke tearDown even if the test method fails exercise"
theme: Toha

menu:
  sidebar:
    name: "Exercise: Invoke tearDown even if the test method fails"
    identifier: exercise-2
    parent: test-driven-development
    weight: 800
---
{{< alert type="warning" >}}
To gain a better understanding of the context, begin by reading the contents of the [xUnit/ch18](https://github.com/Sk3pper/test-driven-development-by-example/tree/main/xUnit) directory, where you will find the relevant code and tests that illustrate the concepts discussed in this chapter.
{{< /alert >}}

# Exercise: Invoke tearDown even if the test method fails
Implement the task **Invoke tearDown even if the test method fails**.

## Step 0: Remove setUp OK prints
After some usage I convinced myself that the `(setUp: OK)` is not necessary. So i remove it leaving only the exception handler in the `TestCase` class during the `self.setUp()` call.

## Step1: Add a little test.
We start from the last one: **Invoke tearDown even if the test method fails**. From what I see in the code:
```python
def run(self, result):
    result.testStarted()

    try:
        self.setUp()
    except Exception as e:
        if e.args: print(e)
        result.testFailed()

    try:
        method = getattr(self, self.name)
        method()
    except Exception as e:
        if e.args: print(e)
        result.testFailed()

    self.tearDown()
    return result
```

When the test method fails the `tearDown()` method is called in any case. Create a test to check it.

```python
def testTearDownWithTestMethodError(self):
    test = WasRun("testBrokenMethod") 
    test.run(self.result)
    assert("setUp tearDown " == test.log)
```

The test checks what happens when `testBrokenMethod` is called. If we see the string `"setUp tearDown "` in the log, it means that both the `setUp` and `tearDown` methods were called correctly.

## Step2: Run all tests and fail + Step3: Make a change + Step4: Run the tests and succeed
In this case the tests do not fail because the current item is already implemented.

```bash
testTemplateMethod: 		        1 run, 0 failed
testResult: 			            1 run, 0 failed
testFailedResultFormatting: 	    1 run, 0 failed
testFailedResult: 		            1 run, 0 failed
testSetUpError: 		            1 run, 0 failed
testTearDownWithTestMethodError: 	1 run, 0 failed
```