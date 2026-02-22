import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'parse_controller.dart';

class ParsePage extends StatelessWidget {
  const ParsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ParseController());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('链接解析')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明文字
            Text(
              '粘贴直播间链接，支持B站、斗鱼、虎牙、抖音',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // 输入框
            TextField(
              controller: controller.textController,
              decoration: InputDecoration(
                hintText: '输入或粘贴直播间链接',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste, size: 20),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      controller.textController.text = data!.text!;
                    }
                  },
                ),
              ),
              onSubmitted: (_) => controller.parse(),
            ),
            const SizedBox(height: 12),
            // 解析按钮
            Obx(() => FilledButton(
                  onPressed:
                      controller.isParsing.value ? null : controller.parse,
                  child: controller.isParsing.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('解析'),
                )),
            const SizedBox(height: 20),
            // 错误信息
            Obx(() {
              if (controller.errorMsg.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  controller.errorMsg.value,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              );
            }),
            // 解析结果
            Obx(() {
              if (controller.parsedRoomId.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('解析结果',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 12),
                      _buildResultRow(
                          context, '平台', controller.parsedPlatform.value),
                      const SizedBox(height: 8),
                      _buildResultRow(
                          context, '房间ID', controller.parsedRoomId.value),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: controller.goToLiveRoom,
                          icon: const Icon(Icons.live_tv, size: 18),
                          label: const Text('进入直播间'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
