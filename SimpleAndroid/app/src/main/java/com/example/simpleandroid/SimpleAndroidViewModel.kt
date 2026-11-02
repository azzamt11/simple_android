package com.example.simpleandroid

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import com.example.simpleandroid.data.HomeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

@HiltViewModel
class SimpleAndroidViewModel @Inject constructor(
    repository: HomeRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(repository.getGreeting())
    val uiState: StateFlow<String> = _uiState.asStateFlow()
}