await new Promise(r => setTimeout(r, 0));
const main = async (e) => ({
    statusCode: 200,
    isBase64Encoded: false,
    body: 'hello'
});

export { main }