# Focus - Self Driving Product Strategy

What is Self Driving Focus App?

1. It is capable of coding itself - Possible with agentic coding and a custom agent github account
2. It is capable of testing itself - Possible with an automated pipeline and a E2E testing
3. It is capable of receiving and managing requests - Possible with Github Integration

## Product Visibility

Parallel to that, we want to have clear visibility of what was delivered. That also will be driven by the Self Driving Strategy, and will work very simply:

1. Every PR that is merged produces a new release, which contains the artifacts tested (like the list of description and the video working - everything automated).
2. Every end of week or so, a human must manually publish a new demo with the compilation of everything that was delivered that day. This demo must be very concrete and the public are laymen people who don't have a clue about the product. The main idea is cellebrating what was done and showcasing in a very intuitive way what was the value delivered.

## Detailed plan

For it to work, let's take what we already have and answer each of the questions:

### 1. It is capable of coding itself

- We can easily use OpenCode for this
- We need to validate if we can fully use opencode inside raspberry pi to manage the code, or if we need to connect it to another computer
- Option: we can try out Pi https://composio.dev/content/pi-vs-opencode 

### 2. It is capable of testing itself

- This is a bigger challenge. 
- Unit tests can be readily put on the pipeline, however we want visual outputs, that will be material for the human and machine to validate.
- Maestro is an option, but we need to see how much it costs and if there is no other alternative - It is possible to use maestro locally.
- Two options: (1) either use maestro with my computer or (2) use a browser solution. Id go with 1 anyway bcs with a browser solution it seems we are not in mobile.

### 3. It is capable of receiving and managing requests

- We need to maintain and work on a github actions integration
- When receiving a new issue, we should have a focus agent github app that will 
- Listen, ask any doubts and execute the job, run the pipeline then merge and show the release when done.
- Interesting: https://github.com/CopilotKit/openbot
- Repokeeper seems interesting: https://github.com/shenxianpeng/repokeeper it works on top of pi

## First iteration:

Use Repokeeper as basis for Github Interaction, use pi.dev (already integrated in Repokeeper), and leave maestro on my local computer so I can run and "homolog" it locally. It is actually a good part of the workflow that I will be involved in.

So the steps are:

1. Create a staging environment - this is needed otherwise it will be a pain to create and manage mocked scenarios, and we also can test backend this way.
2. Create a basic test suite and make it work on maestro locally.
3. Create a basic set of required CLI steps - do the basic before I run in my computer and the code is broken.
4. Integrate repokeeper for coordinating all of this.

