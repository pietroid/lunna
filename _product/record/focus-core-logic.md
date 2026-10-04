# Focus: Core Logic

This document consolidates many of the ideas around focus in a single, opinionated and elegant solution that will drive the core logic for Focus.

## Base structure: Threads

Everything is, initially, a thread. A thread is pretty much like a chat but we take here more care of its living cycle. 

- A thread is a sequence of messages between people and focus agents.
- A thread can be active (pending) or inactive (solved). 

### Home Page

The home page is basically an inbox of threads, with each with its own context.

#### TODO Lists

Because of the old focus behavior (of TODO lists), we are still preserving this structure, disguising a TODO list as also a series of threads. 

### Creating a thread

The user can start a thread from a single place: the text input in the home page. 

For sake of simplicity, the user can either

1. Write down anything to leave as a todo, without instant reply from any Agent.
2. Write down anything as a question or a left prompt for instant reply from Agent.

It's useful sometimes when you want to create something but without instant reply from any agent, because you just want to create a TODO item.

### Reply from Agent

Absolutely anything is expected as an input, and that's where the power of Focus comes from: it may seem that threads are just chats, but no. The idea of threads is to reflect open threads on your own mind, things that you would need to keep neurons running in a loop instead of just relaxing.

Threads solve exactly that: you can release any information from your mind and walk towards a resolution. 

That's what differ fundamentally from just a generic chat. It isn't a mean to just exchange information with agents, but the idea is mainly to close that thread and solve it.

And that's where the agents role are fundamental too. Agents will never give just plain content, unless asked. They will do their best to _act_ and to give user possibilites of _actions_ until the thread is solved.

### Actions

Focus can act by itself by integrating with:

- Calendar
- Web Search
- API Integrations

but also can ask user details through the usage of Generative UI.

### Generative UI

We let the response from Agent to be outside a traditional chat bubble because we want this to be as smart UI as possible.

The Generative UI uses google A2UI structure and a catalog of a specific set of components, which actually is a subset of the current Design System.

