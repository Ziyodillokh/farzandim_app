package com.farzandim.farzandim_child

/**
 * 5 daqiqalik watchdog alarm qabul qiluvchisi — manifestda `exported="false"`:
 * faqat o'zimizning AlarmManager PendingIntent'imiz chaqira oladi. Mantiq
 * [BootReceiver] bilan bir xil (servislarni tiklash + "parvoz:tick").
 */
class WatchdogReceiver : BootReceiver()
