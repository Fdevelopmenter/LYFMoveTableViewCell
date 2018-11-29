//
//  ViewController.m
//  Test-MoveTableViewCell
//
//  Created by 李玉枫 on 2018/11/28.
//  Copyright © 2018 李玉枫. All rights reserved.
//

#import "ViewController.h"

#define kScreenWidth  [[UIScreen mainScreen] bounds].size.width
#define kScreenHeight [[UIScreen mainScreen] bounds].size.height

typedef NS_ENUM(NSInteger, LYFTableViewType) {
    /// 顶部
    LYFTableViewTypeTop,
    /// 底部
    LYFTableViewTypeBottom
};

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

/// 列表
@property (nonatomic, strong) UITableView *tableView;
/// 数据
@property (nonatomic, strong) NSMutableArray *datas;

/// 记录手指所在的位置
@property (nonatomic, assign) CGPoint longLocation;
/// 对被选中的cell的截图
@property (nonatomic, strong) UIView *snapshotView;
/// 被选中的cell的原始位置
@property (nonatomic, strong) NSIndexPath *oldIndexPath;
/// 被选中的cell的新位置
@property (nonatomic, strong) NSIndexPath *newestIndexPath;
/// 定时器
@property (nonatomic, strong) CADisplayLink *scrollTimer;

/// 滚动方向
@property (nonatomic, assign) LYFTableViewType scrollType;

@end

static NSString *cellId = @"cell";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.datas = [NSMutableArray arrayWithArray:@[[NSMutableArray arrayWithArray:@[@"老大", @"老二", @"老三", @"老四", @"老五", @"老六", @"老七", @"老八", @"老九", @"老十"]], [NSMutableArray arrayWithArray:@[@"老1", @"老2", @"老3", @"老4", @"老5", @"老6", @"老7", @"老8", @"老9", @"老10"]]]];
    [self.tableView reloadData];
}

#pragma mark - 对cell进行截图，并且隐藏
-(void)snapshotCellAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    /// 截图
    UIView *snapshot = [self snapshotView:cell];
    /// 添加在UITableView上
    [self.tableView addSubview:snapshot];
    self.snapshotView = snapshot;
    /// 隐藏cell
    cell.hidden = YES;
    CGPoint center = self.snapshotView.center;
    center.y = self.longLocation.y;
    /// 移动截图
    [UIView animateWithDuration:0.2 animations:^{
        self.snapshotView.transform = CGAffineTransformMakeScale(1.03, 1.03);
        self.snapshotView.alpha = 0.98;
        self.snapshotView.center = center;
    }];
}

#pragma mark - 截图对应的cell
- (UIView *)snapshotView:(UIView *)inputView {
    // Make an image from the input view.
    UIGraphicsBeginImageContextWithOptions(inputView.bounds.size, NO, 0);
    [inputView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Create an image view.
    UIView *snapshot = [[UIImageView alloc] initWithImage:image];
    snapshot.center = inputView.center;
    snapshot.layer.masksToBounds = NO;
    snapshot.layer.cornerRadius = 0.0;
    snapshot.layer.shadowOffset = CGSizeMake(-5.0, 0.0);
    snapshot.layer.shadowRadius = 5.0;
    snapshot.layer.shadowOpacity = 0.4;
    
    return snapshot;
}

#pragma mark - 长按手势
-(void)longPressGestureRecognized:(UILongPressGestureRecognizer *)longPress {
    UIGestureRecognizerState longPressState = longPress.state;
    //长按的cell在tableView中的位置
    self.longLocation = [longPress locationInView:self.tableView];
    //手指按住位置对应的indexPath，可能为nil
    self.newestIndexPath = [self.tableView indexPathForRowAtPoint:self.longLocation];
    switch (longPressState) {
        case UIGestureRecognizerStateBegan:{
            //手势开始，对被选中cell截图，隐藏原cell
            self.oldIndexPath = [self.tableView indexPathForRowAtPoint:self.longLocation];
            if (self.oldIndexPath) {
                [self snapshotCellAtIndexPath:self.oldIndexPath];
            }
            break;
        }
        case UIGestureRecognizerStateChanged:{//点击位置移动，判断手指按住位置是否进入其它indexPath范围，若进入则更新数据源并移动cell
            //截图跟随手指移动
            CGPoint center = _snapshotView.center;
            center.y = self.longLocation.y;
            self.snapshotView.center = center;
            if ([self checkIfSnapshotMeetsEdge]) {
                [self startAutoScrollTimer];
            }else{
                [self stopAutoScrollTimer];
            }
            //手指按住位置对应的indexPath，可能为nil
            self.newestIndexPath = [self.tableView indexPathForRowAtPoint:self.longLocation];
            if (self.newestIndexPath && ![self.newestIndexPath isEqual:self.oldIndexPath]) {
                [self cellRelocatedToNewIndexPath:self.newestIndexPath];
            }
            break;
        }
        default: {
            //长按手势结束或被取消，移除截图，显示cell
            [self stopAutoScrollTimer];
            [self didEndDraging];
            break;
        }
    }
}

#pragma mark - 检查截图是否到达边缘，并作出响应
- (BOOL)checkIfSnapshotMeetsEdge{
    CGFloat minY = CGRectGetMinY(self.snapshotView.frame);
    CGFloat maxY = CGRectGetMaxY(self.snapshotView.frame);
    if (minY < self.tableView.contentOffset.y) {
        self.scrollType = LYFTableViewTypeTop;
        return YES;
    }
    if (maxY > self.tableView.bounds.size.height + self.tableView.contentOffset.y) {
        self.scrollType = LYFTableViewTypeBottom;
        return YES;
    }
    return NO;
}

#pragma mark - 当截图到了新的位置，先改变数据源，然后将cell移动过去
- (void)cellRelocatedToNewIndexPath:(NSIndexPath *)indexPath{
    //更新数据源并返回给外部
    [self updateData];
    //交换移动cell位置
    [self.tableView moveRowAtIndexPath:self.oldIndexPath toIndexPath:indexPath];
    //更新cell的原始indexPath为当前indexPath
    self.oldIndexPath = indexPath;
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_oldIndexPath];
    cell.hidden = YES;
}

#pragma mark - 更新数据源
-(void)updateData {
    //通过DataSource代理获得原始数据源数组
    NSMutableArray *tempArray = self.datas;
    
    //判断原始数据源是否为多重数组
    if ([self arrayCheck:tempArray]) {//是嵌套数组
        if (self.oldIndexPath.section == self.newestIndexPath.section) {//在同一个section内
            [self moveObjectInMutableArray:tempArray[self.oldIndexPath.section] fromIndex:self.oldIndexPath.row toIndex:self.newestIndexPath.row];
        }else{                                                          //不在同一个section内
            id originalObj = tempArray[self.oldIndexPath.section][self.oldIndexPath.item];
            [tempArray[self.newestIndexPath.section] insertObject:originalObj atIndex:self.newestIndexPath.item];
            [tempArray[self.oldIndexPath.section] removeObjectAtIndex:self.oldIndexPath.item];
        }
    }else{                                  //不是嵌套数组
        [self moveObjectInMutableArray:tempArray fromIndex:self.oldIndexPath.row toIndex:self.newestIndexPath.row];
    }
}

#pragma mark - UITableViewDataSource / UITableViewDelegate
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.datas.count;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSMutableArray *data = self.datas[section];
    return data.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPressGestureRecognized:)];
        [cell.contentView addGestureRecognizer:longPress];
    }
    
    NSMutableArray *data = self.datas[indexPath.section];
    cell.textLabel.text = data[indexPath.row];
    
    return cell;
}

#pragma mark - 检测是否是多重数组
- (BOOL)arrayCheck:(NSArray *)array{
    for (id obj in array) {
        if ([obj isKindOfClass:[NSArray class]]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - 将可变数组中的一个对象移动到该数组中的另外一个位置
- (void)moveObjectInMutableArray:(NSMutableArray *)array fromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex{
    if (fromIndex < toIndex) {
        for (NSInteger i = fromIndex; i < toIndex; i ++) {
            [array exchangeObjectAtIndex:i withObjectAtIndex:i + 1];
        }
    }else{
        for (NSInteger i = fromIndex; i > toIndex; i --) {
            [array exchangeObjectAtIndex:i withObjectAtIndex:i - 1];
        }
    }
}

#pragma mark - 开始自动滚动
- (void)startAutoScroll {
    CGFloat pixelSpeed = 4;
    if (self.scrollType == LYFTableViewTypeTop) {//向下滚动
        if (self.tableView.contentOffset.y > 0) {//向下滚动最大范围限制
            [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentOffset.y - pixelSpeed)];
            self.snapshotView.center = CGPointMake(self.snapshotView.center.x, self.snapshotView.center.y - pixelSpeed);
        }
    }else{                                               //向上滚动
        if (self.tableView.contentOffset.y + self.tableView.bounds.size.height < self.tableView.contentSize.height) {//向下滚动最大范围限制
            [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentOffset.y + pixelSpeed)];
            self.snapshotView.center = CGPointMake(self.snapshotView.center.x, self.snapshotView.center.y + pixelSpeed);
        }
    }
    
    ///  当把截图拖动到边缘，开始自动滚动，如果这时手指完全不动，则不会触发‘UIGestureRecognizerStateChanged’，对应的代码就不会执行，导致虽然截图在tableView中的位置变了，但并没有移动那个隐藏的cell，用下面代码可解决此问题，cell会随着截图的移动而移动
    self.newestIndexPath = [self.tableView indexPathForRowAtPoint:self.snapshotView.center];
    if (self.newestIndexPath && ![self.newestIndexPath isEqual:self.oldIndexPath]) {
        [self cellRelocatedToNewIndexPath:self.newestIndexPath];
    }
}

#pragma mark - 拖拽结束，显示cell，并移除截图
- (void)didEndDraging{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:self.oldIndexPath];
    cell.hidden = NO;
    cell.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{
        self.snapshotView.center = cell.center;
        self.snapshotView.alpha = 0;
        self.snapshotView.transform = CGAffineTransformIdentity;
        cell.alpha = 1;
    } completion:^(BOOL finished) {
        cell.hidden = NO;
        [self.snapshotView removeFromSuperview];
        self.snapshotView = nil;
        self.oldIndexPath = nil;
        self.newestIndexPath = nil;
        
        [self.tableView reloadData];
    }];
}

#pragma mark - 创建定时器
- (void)startAutoScrollTimer {
    if (!self.scrollTimer) {
        self.scrollTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(startAutoScroll)];
        [self.scrollTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

#pragma mark - 销毁定时器
- (void)stopAutoScrollTimer {
    if (self.scrollTimer) {
        [self.scrollTimer invalidate];
        self.scrollTimer = nil;
    }
}

#pragma mark - Get方法
-(UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight) style:UITableViewStyleGrouped];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        
        [self.view addSubview:_tableView];
    }
    
    return _tableView;
}

@end
