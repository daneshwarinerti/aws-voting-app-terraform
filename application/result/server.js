var express = require('express'),
    async = require('async'),
    { Pool } = require('pg'),
    cookieParser = require('cookie-parser'),
    path = require('path'),
    app = express(),
    server = require('http').Server(app),
    io = require('socket.io')(server);

var port = process.env.PORT || 80;

// --------------------------------------------------
// PostgreSQL environment variables
// --------------------------------------------------

var postgresHost = process.env.POSTGRES_HOST;
var postgresUser = process.env.POSTGRES_USER;
var postgresPassword = process.env.POSTGRES_PASSWORD;
var postgresDatabase = process.env.POSTGRES_DATABASE || 'voting';

console.log('POSTGRES_HOST:', postgresHost);
console.log('POSTGRES_USER:', postgresUser);
console.log('POSTGRES_DATABASE:', postgresDatabase);

if (!postgresHost ||
    !postgresUser ||
    !postgresPassword) {

  console.error('PostgreSQL environment variables are missing.');
  process.exit(1);
}

// --------------------------------------------------
// PostgreSQL connection
// --------------------------------------------------

var pool = new Pool({
  host: postgresHost,
  user: postgresUser,
  password: postgresPassword,
  database: postgresDatabase,
  port: 5432,

  // AWS RDS PostgreSQL
  ssl: {
    rejectUnauthorized: false
  }
});

// --------------------------------------------------
// Socket.IO
// --------------------------------------------------

io.on('connection', function (socket) {

  socket.emit('message', {
    text: 'Welcome!'
  });

  socket.on('subscribe', function (data) {
    socket.join(data.channel);
  });

});

// --------------------------------------------------
// Connect to PostgreSQL
// --------------------------------------------------

async.retry(
  {
    times: 1000,
    interval: 1000
  },

  function(callback) {

    pool.connect(function(err, client, done) {

      if (err) {

        console.error(
          'Waiting for db: ' + err.message
        );

        callback(err);
        return;
      }

      callback(null, client, done);
    });

  },

  function(err, client, done) {

    if (err) {

      return console.error(
        'Giving up: ' + err
      );

    }

    console.log('Connected to db');

    getVotes(client, done);
  }
);

// --------------------------------------------------
// Get votes from PostgreSQL
// --------------------------------------------------

function getVotes(client, done) {

  client.query(
    'SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote',
    [],

    function(err, result) {

      if (err) {

        console.error(
          'Error performing query: ' + err
        );

      } else {

        var votes =
          collectVotesFromResult(result);

        console.log(
          'Current votes:',
          votes
        );

        io.sockets.emit(
          'scores',
          JSON.stringify(votes)
        );
      }

      setTimeout(
        function() {
          getVotes(client, done);
        },
        1000
      );
    }
  );
}

// --------------------------------------------------
// Convert database result
// --------------------------------------------------

function collectVotesFromResult(result) {

  var votes = {
    a: 0,
    b: 0
  };

  result.rows.forEach(function (row) {

    votes[row.vote] =
      parseInt(row.count);

  });

  return votes;
}

// --------------------------------------------------
// Express
// --------------------------------------------------

app.use(cookieParser());

app.use(express.urlencoded());

app.use(
  express.static(
    __dirname + '/views'
  )
);

app.get('/', function (req, res) {

  res.sendFile(
    path.resolve(
      __dirname,
      'views/index.html'
    )
  );

});

// --------------------------------------------------
// Start server
// --------------------------------------------------

server.listen(port, function () {

  var port =
    server.address().port;

  console.log(
    'App running on port ' + port
  );

});
