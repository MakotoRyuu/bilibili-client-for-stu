import SwiftUI

/// 经典侧滑抽屉容器：
/// - 内容区常驻，抽屉从左侧滑出并盖一层半透明遮罩。
/// - 支持汉堡按钮开合、点遮罩关闭、左右拖拽手势。
struct SideDrawer<Menu: View, Content: View>: View {
    @Binding var isOpen: Bool
    var drawerWidth: CGFloat = 280
    @ViewBuilder var menu: () -> Menu
    @ViewBuilder var content: () -> Content

    // 拖拽过程中的临时位移
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .leading) {
                // 主内容
                content()

                // 遮罩：抽屉打开时出现，点击关闭
                if isOpen || dragTranslation != 0 {
                    Color.black
                        .opacity(dimOpacity)
                        .ignoresSafeArea()
                        .onTapGesture { close() }
                        .allowsHitTesting(isOpen)
                }

                // 抽屉本体
                menu()
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .background(.regularMaterial)
                    .offset(x: drawerOffset)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 2, y: 0)
            }
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85), value: isOpen)
            .gesture(edgeDragGesture)
        }
    }

    // MARK: - 计算

    private var drawerOffset: CGFloat {
        let base = isOpen ? 0 : -drawerWidth
        let dragged = base + dragTranslation
        return min(0, max(-drawerWidth, dragged))
    }

    private var dimOpacity: CGFloat {
        let progress = (drawerOffset + drawerWidth) / drawerWidth // 0...1
        return 0.4 * progress
    }

    private func close() { isOpen = false }

    // MARK: - 手势

    private var edgeDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                // 关闭态：只在靠近左边缘起手才允许滑出
                if !isOpen {
                    guard value.startLocation.x < 40, value.translation.width > 0 else { return }
                    state = value.translation.width
                } else {
                    // 打开态：允许向左收回
                    state = min(0, value.translation.width)
                }
            }
            .onEnded { value in
                let threshold = drawerWidth * 0.35
                if !isOpen {
                    if value.startLocation.x < 40, value.translation.width > threshold {
                        isOpen = true
                    }
                } else {
                    if value.translation.width < -threshold {
                        isOpen = false
                    }
                }
            }
    }
}
