package com.example.simpleandroid.data.auth.di

import com.example.simpleandroid.data.auth.AuthRepository
import com.example.simpleandroid.data.auth.AuthRepositoryImpl
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
abstract class AuthModule {
    @Binds
    abstract fun bindAuthRepository(
        implementation: AuthRepositoryImpl
    ) : AuthRepository
}