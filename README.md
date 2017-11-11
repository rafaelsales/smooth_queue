# Smooth Queue

Simple Redis message queue manager with flow control for Ruby applications.

Smooth Queue manages message queues in Redis making sure that your application don't try process more messages than it
can handle.

# Motivation

Sometimes you don't want to process messages as fast as possible. Wat?

A classic example is when you use a background processing framework (such as ActiveJob or Sidekiq), and you don't want
certain workers to process more than 10 jobs simultaneously even though your background processor can handle more 50
jobs at a time.

But why would you not want to execute every single task in your application as fast as possible? There are a couple
reasons for that:

  1. The processing of certain messages are so expensive that can stress your application and cause slowness in the rest
  of the application.
  Example: given a message type which processing causes more reads on database than usual, when your application needs
  to process many of these messages, the stress on database can cause latency for users and other important tasks

  2. Processing of certain message types takes so much time that you don't want to risk having all your background jobs
  busy processing only one type of message and delaying other critical jobs

  1. You cannot affort computing power to handle excessive load when certain jobs are executed with high concurrency

  3. You want to protect you background job queues from attacks that cause too many messages of the same type

# License

Please see [LICENSE](https://github.com/rafaelsales/smooth-queue/blob/master/LICENSE) for licensing details.
