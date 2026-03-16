class NetworkPrintResult {
  const NetworkPrintResult._internal(this.value);
  final int value;
  static const success = NetworkPrintResult._internal(1);
  static const timeout = NetworkPrintResult._internal(2);
  static const printerConnected = NetworkPrintResult._internal(3);
  static const ticketEmpty = NetworkPrintResult._internal(4);
  static const printInProgress = NetworkPrintResult._internal(5);
  static const scanInProgress = NetworkPrintResult._internal(6);

  String get msg {
    if (value == NetworkPrintResult.success.value) {
      return '成功';
    } else if (value == NetworkPrintResult.timeout.value) {
      return '错误：打印机连接超时';
    } else if (value == NetworkPrintResult.printerConnected.value) {
      return '错误：打印机未连接';
    } else if (value == NetworkPrintResult.ticketEmpty.value) {
      return '错误：打印内容为空';
    } else if (value == NetworkPrintResult.printInProgress.value) {
      return '错误：另一个打印任务正在进行中';
    } else if (value == NetworkPrintResult.scanInProgress.value) {
      return '错误：打印机正在扫描中';
    } else {
      return '未知错误';
    }
  }
}
