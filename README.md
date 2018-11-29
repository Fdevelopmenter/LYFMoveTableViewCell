# LYFMoveTableViewCell
长按移动UITableViewCell

之前写了一篇有关于UICollectionViewCell的长按移动的文章：https://www.jianshu.com/p/3f282ac92c8a。
讲述的是iOS端的UICollectionViewCell的长按移动方式。
同样的方法，在UITableViewCell上面是不能实现的，因为苹果并没有提供：
-(void) beginInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath
这个方法给UITableView。

所以我们要换一种思路去完成这个功能，其实在实现原理上和UICollectionView很相似：
1.我们需要记录长按的Cell的NSIndexPath，然后对其截图，并且将Cell隐藏，之后的移动动作全是对这个截图完成的。
2.在移动的过程中，不停地刷新手势的位置。通过手势位置获取新的NSIndexPath，并且不断地更新数据源，修改UITableViewCell的位置。这时，可以开一个CADisplayLink（定时器，和屏幕刷新率相同的频率调用的。），作用是，当手势滑动到最顶部或者最底部的时候，动态的改变UITableView的contentOffset。
3.结束定时器，销毁截图，显示Cell。

思路其实很简单。喜欢的朋友还可以关注我的简书：https://www.jianshu.com/u/01b7a2dd26e8。
欢迎大家一起研究讨论。
