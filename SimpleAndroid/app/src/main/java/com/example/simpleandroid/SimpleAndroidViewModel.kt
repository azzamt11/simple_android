package com.example.simpleandroid

import androidx.lifecycle.ViewModel
import com.example.simpleandroid.data.HomeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@HiltViewModel
class SimpleAndroidViewModel
    @Inject
    constructor(
        repository: HomeRepository,
    ) : ViewModel() {
        private val _uiState = MutableStateFlow(repository.getGreeting())
        val uiState: StateFlow<String> = _uiState.asStateFlow()
    }
