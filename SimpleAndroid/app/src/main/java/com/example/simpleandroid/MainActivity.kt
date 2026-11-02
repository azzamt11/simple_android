package com.example.simpleandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import dagger.hilt.android.AndroidEntryPoint
import androidx.compose.material3.Button

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val viewModel: SimpleAndroidViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    greeting(
                        message = viewModel.uiState.value,
                        isLoggedIn = viewModel.authState.value,
                        onLoginClick = {
                            viewModel.login("demo@example.com", "password123")
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun greeting(
    message: String,
    isLoggedIn: Boolean,
    onLoginClick: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(message)
        Button(onClick = onLoginClick) {
            Text("Login")
        }
        Text(if (isLoggedIn) "Login successful" else "Not logged in")
    }
}
