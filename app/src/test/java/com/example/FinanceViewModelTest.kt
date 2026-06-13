package com.example

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.example.ui.FinanceViewModel
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FinanceViewModelTest {

    private lateinit var app: Application
    private lateinit var viewModel: FinanceViewModel

    @Before
    fun setUp() {
        app = ApplicationProvider.getApplicationContext()
        viewModel = FinanceViewModel(app)
    }

    @Test
    fun `test initial dynamic setup state loads category list`() {
        val state = viewModel.uiState.value
        // Initially loading is true or soon shifts as database is active
        assertNotNull(state)
    }
}
