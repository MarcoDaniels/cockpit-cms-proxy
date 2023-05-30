const http = require('http')
const https = require('https')
const {Elm} = require('./elm')
const app = Elm.Main.init({
    flags: {
        baseURL: process.env.COCKPIT_BASE_URL,
        token: process.env.COCKPIT_API_TOKEN,
    }
})

app.ports.output.subscribe(({request, response, options, secure}) => {
    request.pipe((secure ? https : http).request(options, (incoming) => {
        response.writeHead(Number(incoming.statusCode), incoming.headers);
        incoming.pipe(response, {end: true})
    }), {end: true})
});

http
    .createServer((request, response) => {
        app.ports.input.send({request, response});
    })
    .listen(process.env.PORT);

console.log(`CockpitCMS proxy at http://localhost:${process.env.PORT}`)