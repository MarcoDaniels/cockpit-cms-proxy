const http = require('http')
const https = require('https')
const {Elm} = require('./elm')
const app = Elm.Main.init({
    flags: {
        baseURL: process.env.COCKPIT_BASE_URL,
        token: process.env.COCKPIT_API_TOKEN,
        assetsPath: process.env.ASSET_PATH_PATTERN,
        targetHost: process.env.TARGET_HOST,
        targetPort: Number(process.env.TARGET_PORT),
    }
})

app.ports.output.subscribe(({request, response, meta}) => {
    if (meta && meta.success) {
        request.pipe((meta.secure ? https : http).request(meta.options, (incoming) => {
            response.writeHead(Number(incoming.statusCode), incoming.headers);
            incoming.pipe(response, {end: true})
        }).on('error', (err) => {
            app.ports.input.send({request, response, meta: {success: false, error: err.message}});
        }), {end: true})
    } else {
        response.statusCode = 500;
        response.end(meta.data);
    }
});

http
    .createServer((request, response) => {
        app.ports.input.send({request, response, meta: {success: true}});
    })
    .listen(process.env.PORT);

console.log(`CockpitCMS proxy at http://localhost:${process.env.PORT}`)