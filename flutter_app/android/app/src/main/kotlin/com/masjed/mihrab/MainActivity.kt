package com.masjed.mihrab

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity keeps one Flutter engine shared with the background media
// service, so the Quran and lessons keep playing with the app in the background.
class MainActivity : AudioServiceActivity()
