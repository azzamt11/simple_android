package com.example.simpleandroid.data

import javax.inject.Inject

class HomeDataSource
    @Inject
    constructor() {
        fun getGreeting(): String = "Hello, Jetpack Compose!"
    }
