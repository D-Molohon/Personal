require('dotenv').config();
const tmi = require('tmi.js');
const mysticList = require('./mysticAnswers.json')

const target_channel = "{INSERT_DESIRED_CHANNEL_HERE}"
const target_twitter = "https://twitter.com/{INSERT_TWITTER_HANDLE_HERE}}"
const target_youtube = "https://www.youtube.com/channel/{INSERT_CHANNEL_HERE}"

// Don't forget to check the .env file in this folder to change the bot name to match the twitch account to be used, along with generating a new token.
const target_botname = "{INSERT_BOT_NAME_HERE}"
const client = new tmi.Client({
    connection: {
        reconnect: true
    },
    channels: [ `${target_channel.toLowerCase()}` ],
	identity: {
		username: process.env.twitchBotUser,
		password: process.env.twitchOAUTHToken
	},
});

client.connect();

let commandList = {
    commands: { 
        description: 'Lists available commands.',
    },
    links: {
        description: 'Posts the URL links to socials.',
    },
    lurk: {
        description: 'Someone in chat indicates they are lurking.',
    },
    unlurk: {
        description: 'Someone in chat indicates they are no longer lurking.'
    },
    hello: {
        description: "Says hello back to the command's user!",
    },
    hug: {
        description: 'Hug someone! (Only uses the first word in their message.)',
    },
    eightball: {
        description: 'Ask a question, and shake the magic eight ball to find an answer.',
    },
    rollthedice: {
        description: 'Roll a specified dice!',
    },
    //Both "shoutout" and "so" check if user is a mod or the streamer before use, also creating a sub category of "Streamer + Mod"-only commands
    shoutout: {
        description: 'Shoutout someone!',
    },
    so: {
        description: 'Shoutout someone!',
    }
}

// Literally just for adding the word "and" to the last command when using "!commands" so it can auto populate the list of commands and broadcast that with the appropriate command.
let commandListVar = JSON.parse(JSON.stringify(commandList))
var lastCommandName = Object.keys(commandListVar)[Object.keys(commandListVar).length-1]
var lastCommandRenamed = `and ${lastCommandName.toString()}`
commandListVar[`${lastCommandRenamed}`] = commandListVar[`${lastCommandName}`]
delete commandListVar[`${lastCommandName}`]
var echoCommands = Object.getOwnPropertyNames(commandListVar);
const echoCommandsFiltered = echoCommands.toString().replace(/,/g, ", ")
// console.log(echoCommandsFiltered)

//eightball function
var mysticAnswer = '0'
var mysticValue = 0
function eightball() {
    mysticValue = Math.floor(Math.random() * 20) + 1;
    mysticValue = (`Answer${mysticValue}`).toString()
    if (mysticValue in mysticList.AnswerList) {
        mysticAnswer = mysticList.AnswerList[mysticValue].answer
    }
}

//rollthedice function
var dicevalue = 0
var dicecalc = 0
function rollthedice(args) {
    dicevalue = Math.floor(args)
    dicecalc = Math.floor(Math.random() * dicevalue + 1)
}

//Join message and auto sending social media links every 30 minutes. 
client.on('connected', () => {
    client.action(target_channel, 'is in your chat.')
    setInterval(() => {
        autosendsocials();
    }, 1000 * 60 * 30);
});

function autosendsocials() {
    client.say(target_channel, `Hope you're enjoying the stream so far! If you want even more of my conent, I can be found at these links on Twitter: ${target_twitter} & YouTube: ${target_youtube}`);
}

//Sub notifications
client.on('submysterygift', (channel, username, numbOfSubs) => {client.say(channel, `@${username} just gifted ${numbOfSubs} subsciptions! THANK YOU SO MUCH!!`);})
client.on('subscription', (channel, username) => {client.say(channel, `@${username} just subscribed! THANK YOU!!`);})
client.on('resub', (channel, username) => {client.say(channel, `@${username} just resubbed! THANK YOU AND WELCOME BACK!!`);})

//When a message is sent in chat, this is the logic to check if it's a command 
client.on('message', (channel, tags, message, self) => {
    if (tags['display-name'] !== target_botname) {
        console.log(`${tags['display-name']}: ${message}`);

        if(self || !message.startsWith('!')) return;
        const args = message.slice(1).split(' ');
        const command = args.shift().toLowerCase();
        const args2 = message.slice(1).split(' ');
        const isQuestion = message.slice(1).endsWith('?');

        if(command in commandList) {
            if(command === 'commands') {
                mysticValue = Math.floor(Math.random() * 20) + 1;
                client.say(channel, `@${tags['display-name']}, the commands are as follows: ${echoCommandsFiltered}! To use them, just type '!' and then the command you want! (Shoutouts/SOs are mod only commands.)`);
            }
            if(command === 'links') {
                client.say(channel, `I can be found at these links on Twitter: ${target_twitter} & YouTube: ${target_youtube}`);
            }
            if(command === 'hello') {
                client.say(channel, `@${tags['display-name']}, hi there!`);
            }
            if(command === 'hug'){
                if (args[0]) {
                    client.say(channel, `@${tags['display-name']} gave @${args[0]} a warm hug.`)           
                } else {
                    client.say(channel, `@${tags['display-name']} that wasn't a valid entry! Please try to hug again.`)   
                }
            }
            if(command === 'rollthedice' && (args2[1])) {
                userdice = Math.floor(args2[1])
                if(Number.isInteger(userdice) === true) {
                    rollthedice(userdice)
                    client.say(channel, `@${tags['display-name']}, your roll was ${dicecalc} on a ${userdice} sided die!`);
                } else {
                    client.say(channel, `@${tags['display-name']}, that was an invalid roll! Try again.`)
                }
            }
            if(command === 'eightball' && (args2[1]) && (isQuestion === true)) {
                eightball()
                client.say(channel, `@${tags['display-name']}, ${mysticAnswer}`);
            }
            if(command === 'lurk') {
                client.say(channel, `@${tags['display-name']} has gone away on an adventure!`);
            }
            if(command === 'unlurk') {
                client.say(channel, `@${tags['display-name']} has come back from their journey!`);
            }
            //Logic for checking if the user who sent the command is a mod, or channel owner, before executing the command.
            if (tags.mod === true || tags.username.toLowerCase() === target_channel.toLowerCase() ) {
                if(command === 'shoutout') {
                    client.say(channel, `Go show some love to @${args} at https://www.twitch.tv/${args}! Give them a follow for me <3`);
                }
                if(command.indexOf('so') === 0) {
                    client.say(channel, `Go show some love to @${args} at https://www.twitch.tv/${args}! Give them a follow for me <3`);
                }
            }
            else return;
        }
    }
});