import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/shop.dart';
import '../services/rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'responsive.dart';

class BalancePill extends StatelessWidget {
  const BalancePill({super.key, required this.balance, this.compact = false});

  final Balance balance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!balance.cardLinked) {
      return _Shell(
        compact: compact,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.credit_card_off, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Tarjeta no vinculada',
                style: AppText.body(13, color: AppColors.warning),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final hint = balance.available.usdHint(context.watch<RateService>().rate);

    return _Shell(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.skyDeep),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  balance.available.bs(),
                  style: AppText.figure(compact ? 14 : 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (hint.isNotEmpty)
            Text(hint, style: AppText.body(10, color: AppColors.grayLight)),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

class AppDialogStyle {
  AppDialogStyle._();

  static const Color background = AppColors.surfaceAlt;

  static ShapeBorder get shape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius));
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.border),
            const SizedBox(height: 20),
            Text(title, style: AppText.display(20), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              message,
              style: AppText.body(14, color: AppColors.grayLight),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop, required this.onTap});

  final Shop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final closed = !shop.isOpen;

    return Opacity(
      opacity: closed ? 0.55 : 1,
      child: AppCard(
        onTap: closed ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ShopLogo(url: shop.logoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shop.name,
                      style: AppText.body(16, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      closed
                          ? 'No está recibiendo pedidos'
                          : [
                              if (shop.category != null) shop.category!,
                              '${shop.itemCount} productos',
                            ].join(' · '),
                      style: AppText.body(
                        12,
                        color: closed ? AppColors.warning : AppColors.grayLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!closed) const Icon(Icons.chevron_right, color: AppColors.skyDeep),
            ],
          ),
        ),
      ),
    );
  }
}

class ShopLogo extends StatelessWidget {
  const ShopLogo({this.url, this.size = 52});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.resolveMedia(url);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved == null
          ? Icon(Icons.storefront, color: AppColors.skyDeep, size: size * 0.46)
          : Image.network(
              resolved,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.storefront, color: AppColors.skyDeep),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
            ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final unavailable = !product.available;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.midnight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                product.iconData,
                color: unavailable ? AppColors.border : AppColors.skyDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: AppText.body(15, weight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    unavailable ? 'Agotado por hoy' : product.price.bs(),
                    style: unavailable
                        ? AppText.body(12, color: AppColors.warning)
                        : AppText.figure(14),
                  ),
                ],
              ),
            ),
            if (!unavailable) _Stepper(qty: qty, onAdd: onAdd, onRemove: onRemove),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, required this.onAdd, required this.onRemove});

  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (qty == 0) {
      return IconButton(
        onPressed: onAdd,
        icon: const Icon(Icons.add_circle, color: AppColors.skyLight, size: 30),
        tooltip: 'Agregar',
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.skyDeep),
          tooltip: 'Quitar uno',
        ),
        SizedBox(
          width: 24,
          child: Text('$qty', textAlign: TextAlign.center, style: AppText.figure(16)),
        ),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle, color: AppColors.skyLight),
          tooltip: 'Agregar uno',
        ),
      ],
    );
  }
}

class OrderStatusRail extends StatelessWidget {
  const OrderStatusRail({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.railIndex < 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(child: Text(status.detail, style: AppText.body(13))),
          ],
        ),
      );
    }

    return Row(
      children: List.generate(OrderStatus.rail.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < status.railIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: done ? AppColors.skyLight : AppColors.border,
            ),
          );
        }
        final index = i ~/ 2;
        final reached = index <= status.railIndex;
        final current = index == status.railIndex;
        return Container(
          width: current ? 16 : 12,
          height: current ? 16 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? AppColors.skyLight : AppColors.border,
            border: current
                ? Border.all(color: AppColors.skyDeep, width: 3)
                : null,
          ),
        );
      }),
    );
  }
}

class TileFrame extends StatelessWidget {
  const TileFrame({super.key, required this.child, this.onTap, this.dimmed = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      enabled: onTap != null,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius + 4),
          border: Border.all(
            color: hovered ? AppColors.skyDeep : AppColors.border,
            width: hovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (hovered ? AppColors.skyDeep : Colors.black)
                  .withValues(alpha: hovered ? 0.22 : 0.18),
              blurRadius: hovered ? 24 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(AppTheme.radius + 4),
            child: InkWell(
              onTap: onTap,
              mouseCursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.body(11, color: color, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class ShopTile extends StatelessWidget {
  const ShopTile({super.key, required this.shop, required this.onTap});

  final Shop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final closed = !shop.isOpen;
    final subtitle = [
      if (shop.category != null && shop.category!.isNotEmpty) shop.category!,
      '${shop.itemCount} productos',
    ].join(' · ');

    return TileFrame(
      onTap: closed ? null : onTap,
      dimmed: closed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 104,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.midnight, AppColors.surfaceAlt],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopLogo(url: shop.logoUrl, size: 72),
                const Spacer(),
                StatusBadge(
                  label: closed ? 'Cerrado' : 'Abierto',
                  color: closed ? AppColors.warning : AppColors.success,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: AppText.body(17, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    closed ? 'No está recibiendo pedidos' : subtitle,
                    style: AppText.body(13,
                        color: closed ? AppColors.warning : AppColors.grayLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (!closed)
                    Row(
                      children: [
                        Text('Ver menú',
                            style: AppText.body(13,
                                color: AppColors.skyLight, weight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 16, color: AppColors.skyLight),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final Product product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final unavailable = !product.available;
    final selected = qty > 0;

    return TileFrame(
      onTap: unavailable || !enabled ? null : onAdd,
      dimmed: unavailable,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                border: Border.all(color: AppColors.skyLight.withValues(alpha: 0.7), width: 1.5),
                borderRadius: BorderRadius.circular(AppTheme.radius + 4),
              )
            : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.midnight, AppColors.surfaceAlt],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    product.iconData,
                    size: 28,
                    color: unavailable ? AppColors.border : AppColors.skyDeep,
                  ),
                ),
                const Spacer(),
                if (product.isCombo)
                  const StatusBadge(label: 'Combo', color: AppColors.skyLight),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Text(
                product.name,
                style: AppText.body(15, weight: FontWeight.w600, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    unavailable ? 'Agotado por hoy' : product.price.bs(),
                    style: unavailable
                        ? AppText.body(13, color: AppColors.warning)
                        : AppText.figure(17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!unavailable && enabled)
                  _Stepper(qty: qty, onAdd: onAdd, onRemove: onRemove),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
