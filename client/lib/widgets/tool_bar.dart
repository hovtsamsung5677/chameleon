import 'package:flutter/material.dart';
import '../models/selection_tool.dart';

/// Toolbar widget with selection tools and actions
class ToolBarWidget extends StatelessWidget {
  final SelectionTool currentTool;
  final double brushSize;
  final Function(SelectionTool) onToolChanged;
  final Function(double) onBrushSizeChanged;
  final VoidCallback onColorPick;
  final VoidCallback onPreview;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final VoidCallback onCancelPreview;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool hasSelection;
  final bool isPreviewMode;
  final Color selectedColor;

  const ToolBarWidget({
    super.key,
    required this.currentTool,
    required this.brushSize,
    required this.onToolChanged,
    required this.onBrushSizeChanged,
    required this.onColorPick,
    required this.onPreview,
    required this.onReset,
    required this.onSave,
    required this.onCancelPreview,
    this.onUndo,
    this.onRedo,
    required this.hasSelection,
    this.isPreviewMode = false,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    // In preview mode, show simplified toolbar
    if (isPreviewMode) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.edit,
              label: 'Редактировать',
              onTap: onCancelPreview,
              enabled: true,
            ),
            _buildActionButton(
              icon: Icons.color_lens,
              label: 'Цвет',
              onTap: onColorPick,
              enabled: true,
            ),
            _buildActionButton(
              icon: Icons.save,
              label: 'Сохранить',
              onTap: onSave,
              enabled: true,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tool selection row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(
                SelectionTool.interactiveSegmentation,
                Icons.auto_fix_high,
              ),
              _buildToolButton(SelectionTool.rectangle, Icons.crop),
              _buildToolButton(SelectionTool.brush, Icons.brush),
              _buildToolButton(SelectionTool.eraser, Icons.cleaning_services),
              _buildToolButton(SelectionTool.fill, Icons.format_color_fill),
            ],
          ),
          const SizedBox(height: 12),

          // Brush size slider (for brush and eraser tools)
          if (currentTool == SelectionTool.brush ||
              currentTool == SelectionTool.eraser)
            Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Размер кисти:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: brushSize,
                        min: 10,
                        max: 100,
                        activeColor: Colors.blue,
                        inactiveColor: Colors.white24,
                        onChanged: onBrushSizeChanged,
                      ),
                    ),
                    Text(
                      '${brushSize.round()}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),

          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Undo button
              _buildActionButton(
                icon: Icons.undo,
                label: 'Отмена',
                onTap: onUndo,
                enabled: onUndo != null,
              ),
              // Redo button
              _buildActionButton(
                icon: Icons.redo,
                label: 'Повтор',
                onTap: onRedo,
                enabled: onRedo != null,
              ),
              // Кнопка выбора цвета с отображением текущего цвета
              GestureDetector(
                onTap: onColorPick,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Цвет',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              _buildActionButton(
                icon: Icons.preview,
                label: 'Превью',
                onTap: hasSelection ? onPreview : null,
                enabled: hasSelection,
              ),
              _buildActionButton(
                icon: Icons.refresh,
                label: 'Сброс',
                onTap: hasSelection ? onReset : null,
                enabled: hasSelection,
              ),
              _buildActionButton(
                icon: Icons.save,
                label: 'Сохранить',
                onTap: hasSelection ? onSave : null,
                enabled: hasSelection,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(SelectionTool tool, IconData icon) {
    final isSelected = currentTool == tool;

    return GestureDetector(
      onTap: () => onToolChanged(tool),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.blue : Colors.white24),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : Colors.white38,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white70 : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
