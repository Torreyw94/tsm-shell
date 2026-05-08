module.exports = function(app){

  console.log("🎵 music-suite routes loading...");

  global.MUSIC_STATE = global.MUSIC_STATE || {
    artists: 12,
    pipeline: 5,
    revenue: 84000
  };

  app.get('/api/music/state', (req, res) => {
    return res.json({
      ok: true,
      state: global.MUSIC_STATE
    });
  });

};
