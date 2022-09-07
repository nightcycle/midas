## Backstory
In 2019 I funded and released a game for my second accelerator program. It was a complete flop, and the most disheartening thing was I couldn't figure out why. All the people who playtested it seemed to enjoy it, and the feedback they provided was often contradictory. After that experience it became my mission to never have to wonder why a game was underperforming again. To accomplish this loft goal I turned to analytics. 

In the years since I have been iterating and improving my analytics tactics. I now know what metrics determine a game's success, and I know what kinds of technology is useful in improving them. I gave a [presentation](https://www.youtube.com/playlist?list=PLOY2F4gvXxadthEoqTcADsiAE6m2q14mg) on topic called "The Midas Method" as a clickbaity way to trick people into watching a video about analytics. In the presentation I discussed what was essentially my theory of everything for Roblox game success. While many seemed to appreciate the theory laid-out in the presentation, I would learn in the following months that many who watched often had trouble putting them into practice due to the immmense technical difficulty of running comprehensive analytics without prior experience. 

So, I decided to create something for both people with no prior experience, as well as something for myself. A comprehensive analytics framework to do all the heavy lifting and let the developer focus on the game. The result is the Midas analytics framework.

## Goals
In designing this framework I created a wish-list for everything I hoped to accomplish:
- Allows for the easy binding of data to events.
- Automatically replicates client-side events and data to the server.
- Provides configurable starter events and data-tracking to gather information that would be useful for any game.
- Avoids sending duplicate data unless specified to keep storage costs low and avoiding hitting API limits.
- Organizes events and data into a consistent hierarchy to keep queries simple.

The result is the Midas framework, useable as a Wally package for any developer who is interested.

## Future
The dream is that you will be able to create a fully interactive Power Bi dashboard from any game within 15 minutes. The result must be modular as well, as many developers have their own existing workflows already and might not be ready to jump over entirely to Midas. Both of these aspirations will inch closer to reality over the subsequent updates. If you'd like to help out with that definitely reach out!
