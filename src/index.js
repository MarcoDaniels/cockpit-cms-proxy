const http = require('http')
const https = require('https')
const {Elm} = require('./elm')
const app = Elm.Main.init({
    flags: {
        baseURL: process.env.COCKPIT_BASE_URL,
        token: process.env.COCKPIT_API_TOKEN,
    }
})

app.ports.output.subscribe(({success, options, secure, data, handler: {request, response}}) => {
    if (success) {
        request.pipe((secure ? https : http).request(options, (incoming) => {
            response.writeHead(Number(incoming.statusCode), incoming.headers);
            incoming.pipe(response, {end: true})
        }).on('error', (err) => {
            app.ports.input.send({success: false, error: err.message, handler: {request, response}});
        }), {end: true})
    } else {
        response.statusCode = 500;
        response.end(data);
    }
});

http
    .createServer((request, response) => {
        app.ports.input.send({success: true, handler: {request, response}});
    })
    .listen(process.env.PORT);

console.log(`CockpitCMS proxy at http://localhost:${process.env.PORT}`)