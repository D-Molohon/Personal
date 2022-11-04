Hello!

This is sort of a general Twitch bot to use and host on your PC while you Stream.
There are a couple of things you'll need to do first:

- Create your bot's Twitch account, log in, and verify it.
- Go to "https://twitchtokengenerator.com/", and make sure you are logged into the bot account in your browser

Once you have the token for your bot:

- In the folder this text document is stored in, open the ".env" file in a text editor (Notepad on Windows, Notepad++ otherwise).
- Between the quotes for "{INSERT_BOT_USER_LOGIN_HERE}", enter the name of your bot so it looks like "MYBOT"
- Do the same for "OAUTH" token, it'll be what allows the bot to automatically log in when we start this all up.

Once the ".env" file is configued, open "server.js" in a text editor of your choosing, and verify that these items are correct:

- "const target_channel"
- "const target_twitter"
- "const target_youtube" 
- "const target_botname"

* Note that if you're not wanting to include YouTube, and only Twitter, or substitute another link instead, this can be edited.
* You'll need to change some things at "function autosendsocials" and "if(command === 'links')"
* You can also change wording around for the commands for the most part, but if you're wanting to do so please let me know.

Thanks for reading this, and please feel free to reach out to me with any questions or if you'd like help tuning the bot to your preferences! :D
