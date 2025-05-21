---
title: "TDD by example"
date: 2025-05-20T06:00:23+06:00
author:
  name: Andrea Bissoli
  # image: /images/author/avatar.png
hero: /images/tdd-icon-hero.png
description: A practical guide to setup, use and practice in TDD style
theme: Toha

menu:
  sidebar:
    name: TDD by example
    identifier: test-driven-development-by-example-init
    parent: test-driven-development
    weight: 800
---

## The Joy of Reading
In recent months, I’ve discovered the **joy of reading**. I started with books far from the world of software development topic, but eventually, I landed on this vast and fascinating topic. Even though I have a Master’s degree in Computer Science and some experience in coding, only now have I found these books and realized the enormous value and knowledge they contain. Better late than never!

What disappoints me is that during university, no one ever pointed me toward these kinds of books. And in my work experience, I’ve never met anyone who advised or encouraged me to explore this path. Of course, I picked up some concepts during my studies and on the job, but it's not the same! On the other hand, maybe if someone had told me to read these books earlier, I wouldn’t have listened anyway. Nevertheless, this is how things happened, and now I’m ready to absorb all this knowledge.

On this topic, I started with *"Clean Code* by Robert C. Martin, followed by *"Refactoring: Improving the Design of Existing Code"* by Martin Fowler. Then I read The  *"Pragmatic Programmer (20th anniversary)*" by David Thomas and Andrew Hunt, and the last one was  *"Test Driven Development by Example"* by Kent Beck.

The **main purpose** of this article is to share my [GitHub repository](https://github.com/Sk3pper/test-driven-development-by-example) with the exercises I did while reading TDD By Example book. I hope it can be useful for others who are walking the same path.

## Lessons learned
The TDD's goal is simple but powerful: **Write clean code that works**. But pay attention, not at the same time! Divide and conquer the problem
  1. First, solve the "*that works*" part
  2. Second, solve the "*clean code*" part
   
The TDD cycle is focused on three stages:
{{< img src="images/tdd-icon.png" align="center" title="TDD" width="400px">}}

1. **Write a test**. Invent the interface you wish you had.
2. **Make it run**. Getting the bar green in seconds (*).
3. **Make it right**. Remove the duplication that you have introduced, and get to green quickly.
   
(*) Three strategies to quickly getting it to run
1. **Fake it** - Return a constant and gradually replace constants with variables until you have the real code.
2. **Use Obvious Implementation** - Type in the real implementation.
3. **Triangulation** - When we triangulate, we only generalize code when we have two examples or more. We briefly ignore the duplication between test and model code. When the second example demands a more general solution, **then and only then** do we generalize.

Another powerful concept is when implementing TDD in code it is possible there are not present adequate tests so **write the tests you whish you had**. 

The last one is when you have clean, well-tested code, you don’t need to overthink every decision. Instead of spending several minutes reasoning through a problem, make the change and run the tests - your test suite can give you an answer in seconds. This is one of the great strengths of TDD: it allows you to experiment confidently. Without tests, you're forced to rely solely on reasoning. With tests, you have the freedom to try something and quickly get feedback.

## The Code
In the [repository](https://github.com/Sk3pper/test-driven-development-by-example) you can find the code for the **Money example** (organized by chapter, just like in the book), along with a guide to set up a minimal, terminal-based environment that lets you follow along with the chapters and clearly see each step of the process.

Additionally, the repository includes **xUnit** code and examples, featuring a clear progression through the implementation inspired by the book. The `xUnit/` directory also includes solutions for the following tasks:

- **Catch and report setUp errors**
- **Invoke tearDown even if the test method fails**
- **Create TestSuite from a TestCase class**
  
These examples demonstrate how to apply *Test-Driven Development (TDD) principles* in practice - step by step. They also served as a way for me to better understand the entire process and train myself through hands-on exercises..
