const express = require('express')
const bodyParser = require('body-parser');


const app = express()
const port = 3000

app.use(express.static('public'))
app.use(bodyParser.json())

app.post('/wifi-connect', (req, res) => {
  res.send('Sent connection settings');
})

app.post('/get-setup-code', (req, res) => {
  res.send('Setup code requested');
})

app.get('/check-status', (req, res) => {
  res.send('Status update ' + Math.floor(Math.random() * Math.floor(100)));
})

app.listen(port, () => {
  console.log(`Listening at http://localhost:${port}`)
})

