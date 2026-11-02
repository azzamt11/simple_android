package com.example.simpleandroid.data.auth

import javax.inject.Inject

interface AuthRepository {
    suspend fun login(email: String, password: String) : Boolean
}