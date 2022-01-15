require('dotenv').config();
const tmi = require('tmi.js');
const mysticList = require('./mysticAnswers.json')

const client = new tmi.Client({
    connection: {
        reconnect: true
    },
    channels: [ 'channelname' ],
	identity: {
		username: process.env.twitchBotUser,
		password: process.env.twitchOAUTHToken
	},
});

client.connect().then((result) => console.log(result));

let commandList = {
    commands: { 
        // exec: "`@${tags.username}, the commands are as follows: ${echoCommandsFiltered}.`",
        // "Commands are..."
        description: 'Lists available commands.',
    },
    socials: {
        // exec: "`I can be found at these links on Twitter: & YouTube:`",
        // "Twitter: & YouTube:"
        description: 'Posts the URL links to socials.',
    },
    hello: {
        // exec: "`@${tags.username}, hello.`",
        // "@User, hello."
        description: 'Says hello back.',
    },
    // uptime: {
    //     // exec: "`Stream has been up for: $(twitch channelname {{uptimeLength}})`",
    //     // "Stream has been up for: uptimeLength"
    //     description: "Posts the current stream's uptime.",
    // },
    eightball: {
        // exec: "`eightball(); 
        // `@${tags.username}, ${mysticAnswer}`);",
        // "Random answer ball."
        description: 'Ask a question, and shake the magic eight ball to find an answer.',
    },
}

// Literally just for adding the word "and" to the last command when using "!commands" so it can auto populate the list of commands and broadcast that with the appropriate command.
let commandListVar = JSON.parse(JSON.stringify(commandList))
var lastCommandName = Object.keys(commandListVar)[Object.keys(commandListVar).length-1]
var lastCommandRenamed = `and ${lastCommandName.toString()}`
commandListVar[`${lastCommandRenamed}`] = commandListVar[`${lastCommandName}`]
delete commandListVar[`${lastCommandName}`]
var echoCommands = Object.getOwnPropertyNames(commandListVar);
const echoCommandsFiltered = echoCommands.toString().replace(/,/g, ", ")
console.log(echoCommandsFiltered)

//Eightball function
var mysticAnswer = '0'
var mysticValue = 0
function eightball() {
    mysticValue = Math.floor(Math.random() * 20) + 1;
    mysticValue = (`Answer${mysticValue}`).toString()
    if (mysticValue in mysticList.AnswerList) {
        mysticAnswer = mysticList.AnswerList[mysticValue].answer
    }
}

client.on('message', (channel, tags, message, self) => {
    const botCheck = tags.username.toLowerCase() !== process.env.twitchBotUser;
    if (botCheck) {
        console.log(`${tags['display-name']}: ${message}`);

        if(self || !message.startsWith('!')) return;
        const args = message.slice(1).split(' ');
        const command = args.shift().toLowerCase();
        const args2 = message.slice(1).split(' ');
        const isQuestion = message.slice(1).endsWith('?');

        if(command in commandList) {
            // var execString = commandList[command].exec
            // execString = execString.toString().replace(/`/g, '')
            if(command === 'commands') {
                mysticValue = Math.floor(Math.random() * 20) + 1;
                client.say(channel, `@${tags.username}, the commands are as follows: ${echoCommandsFiltered}.`);
            }
            if(command === 'socials') {
                client.say(channel, `I can be found at these links on Twitter: & YouTube:`);
            }
            if(command === 'hello') {
                client.say(channel, `@${tags.username}, hello.`);
            }
            // if(command === 'uptime') {
            //     client.say(channel, `Stream has been up for: $(twitch channelname "{{uptimeLength}})"`);
            // }
            if(command === 'eightball' && (args2[1]) && (isQuestion === true)) {
                eightball();
                client.say(channel, `@${tags.username}, ${mysticAnswer}`);
            }
            else return;
        }
    }
});