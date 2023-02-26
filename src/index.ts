import {asNumber, asString, environmentDecoder} from 'environment-decoder'
import http from 'http'
import https from 'https'
import {match, P} from 'ts-pattern'
import {parse} from 'url'

const env = environmentDecoder({
    COCKPIT_API_TOKEN: asString,
    COCKPIT_BASE_URL: asString,
    TARGET_HOST: asString,
    TARGET_PORT: asNumber,
    PORT: asNumber
})


http.createServer((incomingMessage, serverResponse) =>
    match(incomingMessage)
        .with({url: P.when((p) => p.startsWith('/image/api/'))}, ({url}) => {
            const {pathname, search} = parse(url, true)
            const path = pathname?.replace('/image/api', "")

            const host = (env.COCKPIT_BASE_URL).replace("https://", "")
            const options: http.RequestOptions = {
                host: host,
                path: "/api/cockpit/image?token="
                    + env.COCKPIT_API_TOKEN
                    + "&src=" + env.COCKPIT_BASE_URL + "/storage/uploads"
                    + path + "&" + search?.substring(1),
                method: incomingMessage.method,
                headers: {...incomingMessage.headers, host: host},
            }

            https.get(options, (backIncomingMessage) => {
                serverResponse.writeHead(Number(backIncomingMessage.statusCode), backIncomingMessage.headers)
                backIncomingMessage.pipe(serverResponse, {end: true})
            })
        })
        .otherwise(() => {
            const options = {
                port: env.TARGET_PORT,
                hostname: env.TARGET_HOST,
                path: incomingMessage.url,
                method: incomingMessage.method,
                headers: incomingMessage.headers,
            }

            const backendRequest = http.request(options, (backendIncomingMessage) => {
                serverResponse.writeHead(Number(backendIncomingMessage.statusCode), backendIncomingMessage.headers)
                backendIncomingMessage.pipe(serverResponse, {end: true})
            })

            incomingMessage.pipe(backendRequest, {end: true})
        })
).listen(env.PORT)

console.log(`CockpitCMS proxy at http://localhost:${env.PORT}`)