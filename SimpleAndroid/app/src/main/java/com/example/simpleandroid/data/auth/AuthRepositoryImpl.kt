package com.example.simpleandroid.data.auth

import javax.inject.Inject

class AuthRepositoryImpl @Inject constructor() {
    override suspend fun login(email: String, password: String) : Boolean = false
}