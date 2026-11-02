package com.example.simpleandroid.data

import javax.inject.Inject

class HomeRepository @Inject constructor(
    private val dataSource: HomeDataSource
) {
    fun getGreeting(): String = dataSource.getGreeting()
}