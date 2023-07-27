package dev.steenbakker.flutter_ble_peripheral
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.internal.synchronized
import kotlin.coroutines.*

class JobQueue {
    private val scope = MainScope()
    private val queue = Channel<Job>(Channel.UNLIMITED)

    init {
        scope.launch(Dispatchers.Default) {
            for (job in queue) job.join()
        }
    }

    fun submit(
        context: CoroutineContext = EmptyCoroutineContext,
        block: suspend CoroutineScope.() -> Unit
    ) {
        val job = scope.launch(context, CoroutineStart.LAZY, block)
        queue.trySend(job)
    }

    fun cancel() {
        queue.cancel()
        scope.cancel()
    }
}