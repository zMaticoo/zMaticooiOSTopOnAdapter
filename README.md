# TopOnzMaticooAdapter

zMaticoo iOS SDK ↔ TopOn mediation adapter（AnyThinkiOS / TPNiOS）。

## Version

`2.2.0.2`

## Integration

| Subspec | 代码 | 依赖 | 说明 |
|---------|------|------|------|
| `Latest`（默认） | `Classes/` | `AnyThinkiOS` | 新 API |
| `Legacy` | `ClassesLegacy/` | `AnyThinkiOS <= 6.4.92` | 旧 API |
| `LatestTPN` | `Classes/` | `TPNiOS` | 新 API，宿主用 TPNiOS 时选这个 |
| `LegacyTPN` | `ClassesLegacy/` | `TPNiOS <= 6.4.92` | 旧 API，宿主用 TPNiOS 时选这个 |

```ruby
# Latest + AnyThinkiOS（默认）
pod 'TopOnzMaticooAdapter', '2.2.0.2'

# Legacy + AnyThinkiOS
pod 'TopOnzMaticooAdapter', '2.2.0.2', :subspecs => ['Legacy']

# Latest + TPNiOS（宿主已接 TPNiOS，避免与 AnyThinkiOS 撞 framework）
pod 'TopOnzMaticooAdapter', '2.2.0.2', :subspecs => ['LatestTPN']

# Legacy + TPNiOS
pod 'TopOnzMaticooAdapter', '2.2.0.2', :subspecs => ['LegacyTPN']
```

> 同一 target：**Latest\* / Legacy\*** 只能选其一；**AnyThink / TPN** 也只能选其一。
