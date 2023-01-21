import {asString, environmentDecoder} from 'environment-decoder'
import http from 'http'
import https from 'https'
import {URL} from 'url'
import {match, P} from 'ts-pattern'

const env = environmentDecoder({
    COCKPIT_API_TOKEN: asString,
    COCKPIT_BASE_URL: asString,
})

http.createServer((incomingMessage, serverResponse) => {

    if (incomingMessage.url) {
        const parseURL = new URL(incomingMessage.url)

        match(parseURL)
            .with({pathname: P.when((p) => p.startsWith('/image/api/'))}, ({pathname, search}) => {
                const path = pathname.replace('/image/api', "")
                const host = (env.COCKPIT_BASE_URL).replace("https://", "")

                const options: http.RequestOptions = {
                    host: host,
                    path: "/api/cockpit/image?token=" + env.COCKPIT_API_TOKEN + "&src=" + env.COCKPIT_BASE_URL + "/storage/uploads" + path + "&" + search,
                    method: incomingMessage.method,
                    headers: {...incomingMessage.headers, host: host},
                }

                https.get(options, (backIncomingMessage) => {
                    serverResponse.writeHead(Number(backIncomingMessage.statusCode), backIncomingMessage.headers)
                    backIncomingMessage.pipe(serverResponse, {end: true})
                })
            })
            .otherwise(({hostname, pathname}) => {
                const options = {
                    host: hostname,
                    port: 1234,
                    path: pathname,
                    method: incomingMessage.method,
                    headers: incomingMessage.headers,
                }

                const backend_req = http.request(options, (backIncomingMessage) => {
                    serverResponse.writeHead(Number(backIncomingMessage.statusCode), backIncomingMessage.headers)
                    backIncomingMessage.on('data', (chunk) => {
                        serverResponse.write(chunk)
                    })
                    backIncomingMessage.on('end', () => {
                        serverResponse.end()
                    })
                })

                incomingMessage.on('data', (chunk) => {
                    backend_req.write(chunk)
                })
                incomingMessage.on('end', () => {
                    backend_req.end()
                })
            })
    }

}).listen(8000)

console.log(`running dev in http://localhost:8000`)