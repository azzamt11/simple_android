package com.example.simpleandroid.data.auth

import javax.inject.Inject

class AuthRepositoryImpl @Inject constructor() : AuthRepository {
    override suspend fun login(email: String, password: String): Boolean {
        return email == "demo@example.com" && password == "password123"
    }
}
