# 多线程下载图片
                                                                                         Acery - 2017.9.29
     
## 总体的步骤

![网络和多线程的基础架构](media/15376270710399/%E7%BD%91%E7%BB%9C%E5%92%8C%E5%A4%9A%E7%BA%BF%E7%A8%8B%E7%9A%84%E5%9F%BA%E7%A1%80%E6%9E%B6%E6%9E%84.png)


* 我们希望从网上下载数据的过程是在子线程上执行的，但在在这个过程中我们需要保证涉及到UI更新的操作都必须在主线程上执行（一般出现在数据下载完毕的时候），所以我们将会进行线程的跳转。

* 再来讨论一下缓存，缓存的目的是为了节省下载的时间和流量，所以我们把下载下来的图片用字典的方式组织起来放在内存中，这样在每次cell即将显示的时候就不需要从网络获取。那么程序退出，内存完全释放呢？我们可以将这个数据保存在本地，接着加入数据源中（之前的数据源有内存和网络），他们合理的层次结构是：内存 -> 本地 -> 网络，就如上图描述的一样。

* 现在我想应该可以开始描述这个功能了！

## 创建tableView
我们需要下载的是图片，可以用tableView的cell来作为它的容器，所以我们需要创建一个model去描述每个cell：

```objc
//
//  ACCellModel.h
//  MDDownloadDemo
//
//  Created by Acery on 2016/9/22.
//  Copyright © 2016年 Acery. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ACCellModel : NSObject

@property (strong ,nonatomic) NSString *url;

@property (strong ,nonatomic) NSString *title;

@property (assign ,nonatomic) NSInteger downloadCount;

+(instancetype)modelWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END

//在提供属性的同时，提供一个快速从字典穿件model的类方法是一个模型的常见方法，你可以用KVC实现这个方法或者依次赋值。
//NS_ASSUME_NONNULL_BEGIN 和 NS_ASSUME_NONNULL_END 是一对宏它的作用是：在这之间的所有方法的参数都不能为空。
```

接着在AppDelegate.m的中

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
```
方法中创建tableViewController，让它成为window的根控制器，现在我们能在自定义tableView
Controller的实现文件中开始我们的全部描述。

接下来想想我们可能会用到那些属性：
```objc
//我们可能需要用到一个可变字典来组织图片的缓存，为什么是字典？这样能避免读取时发生的错误，因为字典的key和value是唯一对应的。
@property (strong, nonatomic ) NSMutableDictionary<NSString *,UIImage *> *images;
//接下来我们可能需要用到一个数组来保存所有的model
@property (strong, nonatomic ) NSMutableArray<ACCellModel *> *models;
//也许我们还会将所有的下载任务保存起来
@property (strong, nonatomic ) NSMutableDictionary<NSString *,NSBlockOperation *> *operations;
//为了不频繁的创建队列我们也应该让它成为类的属性，在需要的时候创建一次
@property (strong, nonatomic )NSOperationQueue *myQueue;
//在所有的数组和字典中我明确的规定了元素的类型，这样能有效的防止一些错误！
```
* 接下来是创建这些属性的懒加载方法。

* 然后是设置tableView的数据，当然是根据模型来设置。

* 这样一来我们的tabelView创建的就差不多了！

## 在cellForRowAtIndexPath方法中
在这个方法中我们将花很多时间去实现功能（因为这个方法循环利用了每个cell，我们需要在这个cell返回之前给他们设置正确的图片）：
```objc
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    
   //添加代码。。。
    return cell;
}
```
也许在第一次你会不知道先从上图的哪一步开始，我们假设现在内存中已经有了所有的图片缓存，所以我们将会从images取出我们的图片，这里的key我直接使用了每张图片的网络地址因为它们相对是唯一的。实际上我们取出的图片不一定存在，因为有可能他们没有内存缓存，之前都是我们假设的，所以这样的代码就合情合理的出现了，能理解这一点很重要，包活本地缓存的实现也将用到这种思考模式（if --- do）：

```objc
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    
     /*设置图片*/
    //先去内存缓存中找
    
    UIImage *image = [self.images objectForKey:model.url];
    
    if (image == nil)
    {
        //没有内存缓存
    else
    {
      //有内存缓存
      cell.imageView.image = image;
    }
    return cell;
}
```

### 从本地读取缓存
接着当我们发现没有内存缓存的时候应该从本地读取本地缓存，它也可能不存在（有可能没下载过，或者第一次打开应用程序），我们需要从网络上下载。但在这之前我们先先描述一下路径的问题，涉及到IO操作的都离不开路径和线程：
* 文件应该放在哪里？

* 路径怎么拼接？

-------
    
* Apple在沙盒中提供了三个文件夹给我使用：
    * Documents

    这个目录将会被iTunes备份，所以一般存放一些用户重要的数据，很显然并不适合放这个文件夹。
    * Library

    这个文件目录有两个子目录：
    
        Preferences:存放用户的偏好设置
        Caches:存放一些应用程序再次启动的时候需要用到的数据
        这个文件夹可以创建新的文件夹，同时除了Caches文件夹，其他的文件夹都会被iTunes备份
    * tmp

    这个文件夹用来存放一些零时的数据，但他不知道什么时候会被清理。
    
        所以最适合的文件夹应该是Caches
        
-------
NSstring 和 NSPathUtilities两个类提供了一些方法来拼接我们的路径：
```objc
//获取caches文件夹的全路径，iOS是不能使用非全路径的，所以这里要把路径展开，同时获取到的是一个数组，因为这个函数在Macos也能使用，所以应该获取第一个对象。
NSString *path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
//获取路径的最后一段的字符串：就像https://wow.blizzard.cn/landing，只会获得landing这一段，在这里我们把这一段作为缓存图片的名称，当然你可以把整个URL做MD5加密的结果作为名称。
NSString *name = model.url.lastPathComponent;
//拼接路径字符串，自带/。
NSString *allPath = [path stringByAppendingPathComponent:name];
```

接下来我们可以轻松的获取这个图片和把图片写入本地的Caches文件夹。

### 下载图片（开启子线程）
接下来我想重点应该要来了，但是在这之前你应该理解下面这段由上面一步步描述下来的代码：
```objc
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    
    //获取模型
    ACCellModel *model = self.models[indexPath.row];
    

    //磁盘缓存路径
    NSString *path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *name = model.url.lastPathComponent;
    NSString *allPath = [path stringByAppendingPathComponent:name];

    NSLog(@"%@",allPath);

    /*设置图片*/
    //先去内存缓存中找

    UIImage *image = [self.images objectForKey:model.url];

    if (image == nil)
    {
        //内存缓存没有
        /*去磁盘缓存寻找*/
        NSData *data = [NSData dataWithContentsOfFile:allPath];
        UIImage *imageDisk = [UIImage imageWithData:data];

        if (imageDisk == nil)//如果没有磁盘缓存
        {
           //下载图片
        }
        else
        {
            //磁盘中有缓存
            NSLog(@"磁盘");
            [self.images setObject:imageDisk forKey:model.url];
            cell.imageView.image = imageDisk;
        }
    }
    else
    {
        NSLog(@"内存");
        cell.imageView.image = image;

    }

       return cell;
}
```
在下载的过程中我们应该开启子线程去执行整个下载过程，所以第一步我想应该去封装一个任务：
```objc
if (imageDisk == nil)//如果没有磁盘缓存
    {
        //添加下载任务
        NSLog(@"下载");
        //下载文件
        NSBlockOperation *downloadOp = [NSBlockOperation blockOperationWithBlock:^{
            //模拟延迟
            [NSThread sleepForTimeInterval:2];
            //下载的主要操作
            NSURL *downloadURL = [NSURL URLWithString:model.url];
            NSData *imageData = [NSData dataWithContentsOfURL:downloadURL];
            UIImage *imageFromUrl = [UIImage imageWithData:imageData];

            //加入内存缓存
            [self.images setObject:imageFromUrl forKey:model.url];

            //写入磁盘
            [imageData writeToFile:allPath atomically:YES];

        }];
        //添加到队列
        [self.myQueue addOperation:downloadOp];
  }
```

毋庸置疑现在的下载过程中肯定在子线程执行，但是下载完成之后图片并没有重新设置到cell上。因为只有在cell没有设置图片才会来到这里（本地和内存都没有图片），但是这里执行完成之后也没有任何的UI更新操作。

我可以调用
```objc
//用它来刷新单独的一个cell，因为在cellForRowAtIndexPath中同一时间只会创建并设置一个cell。
[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
```
### 线程通讯回到主线程更新cell
接下来我们将面临一个核心的问题，这行代码应该放哪里：
* 首先考虑是在downloadOp里面还是外面：

    如果放在了外面downloadOp是异步执行，所以在刷行cell的时候图片应该还没有下载完毕，所以应该放在downloadOp内部，但这个又产生了一个问题：

* 刷新cell属于UI更新操作，应该在子线程中执行：

    所以这里我们应该进行线程跳转，回到主线程刷新cell，当然是在图片下载完成的时候。

-------

这样一来downloadOp就变成了这样：
```objc
downloadOp = [NSBlockOperation blockOperationWithBlock:^{

    [NSThread sleepForTimeInterval:2];

    NSURL *downloadURL = [NSURL URLWithString:model.url];
    NSData *imageData = [NSData dataWithContentsOfURL:downloadURL];
    UIImage *imageFromUrl = [UIImage imageWithData:imageData];

    //加入内存缓存
    [self.images setObject:imageFromUrl forKey:model.url];

    //写入磁盘
    [imageData writeToFile:allPath atomically:YES];

    [self.operations removeObjectForKey:model.url];

    NSLog(@"thread --- %@",[NSThread currentThread]);

    dispatch_async(dispatch_get_main_queue(), ^{
        //主线程
        //重新加载
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];


    });

}];
```
    我使用了GCD来回到主线程
### 占位图片    
回顾一下整个过程：
* 我们先创建了子线程，他执行了从网络获取图片并加入内存和本地缓存的全部过程。

* 所以当执行完毕的时候我们从子线程更新cell的时候就能从内存中得到缓存。

* 但是如果你的网络状况并不是很好或者图片的URL存在问题下载不了呢？
    * 这意味着你的cell从没图片到有图片需要等待很长时间，Apple提供的cell类型有图片和没图片的界面相差很多，所以我们需要一个占位图片来嚷用户知道这里有张图片，只是他还没加载出来
    * 在哪里这设置占位图片？首先他肯定是在主线程上的，而且是同步执行的方式，所以应该在downloadOp执行之前。这样等到下载完毕刷新cell的时候这个图片将会被覆盖，因为它不可能再来到下载线程中。

    
    **代码应该是这样：**
        
    ```objc
    //设置占位图片
    cell.imageView.image = [UIImage imageNamed:@"display"];
    downloadOp = [NSBlockOperation blockOperationWithBlock:^{
    //下载线程
    }
    ```
    
### 线程任务缓存
之前提到了网络质量很差的情况，我们加载一张图片需要很长的时间，假设现在用户让这个cell消失在屏幕中（他向下滑动了屏幕），接着他又让这个cell重新显示在屏幕中（他又向上滑动来屏幕，显然图片加载不出来让他很着急），这时候图片还没下载完毕，也许是他的网络出现了问题，我们讨论的问题是现在这个cell中的图片被下载了几次？
* 第一次程序刚进来的时候这是理所当然的，现在这个任务正在子线程中执行

* 当这个cell又出现在屏幕中的时候，又有一个相同的任务被添加到队列中，因为之前到图片没有下载完毕，内存和磁盘中都没有缓存，所以它会下载。

问题很严重同样的任务被执行了两次，同时这种情况在网络质量不佳的情况下经常发生，所以我们应该确保同样的下载任务只会被执行一次，最好的方法就是将任务添加到容器中，下次执行任务的时候去容器中取出来，如果容器中没有这个任务则在创建一个新的任务，添加到容器中。

我们用什么容器？

首先我们必须确保每张现在的图片对应这唯一的任务，所以应该用字典保存他们，key可以把model的url拿来用，然后在下载完成的时候删除这个缓存，整个过程是这样：
```objc
//从字典中获取任务
 NSBlockOperation *downloadOp = self.operations[model.url];

    if (downloadOp)
    {
        //下载正在执行
        NSLog(@"正在下载");
    }
    else
    {
        //添加下载任务
        downloadOp = [NSBlockOperation blockOperationWithBlock:^{
        //下载图片
        
        [self.operations removeObjectForKey:model.url];
        }];
        //缓存任务
        [self.operations setObject:downloadOp forKey:model.url];
        //添加到队列
        [self.myQueue addOperation:downloadOp];

    }
```

-------

## 小问题
至此在cellForRowAtIndexPath方法中的代码已经描述了差不多了，但这里还有几个问题需要去解决：
* cell的重用机制：cell的重用机制是否会影响我们的数据呢？因为我们的model这个问题基本上可以不用去想，我们每次获图片的key都是每个cell对应model的url，无论怎么循环那个url还是那个url。

* 内存警告：当我们的cell有很多个的时候对应的内存缓存也会不断的增加，也许我们的应用程序会收到iOS发送的内存警告，为了应用程序还能完美的运行，我们在
```objc
-(void)didReceiveMemoryWarning
{
    //释放内存缓存
}
```
方法中将会释放内存缓存中的所有对象，实际上你可以用NSCache去管理你所有的缓存，它的用法和字典是一样的，只不过管理缓存会简单的许多，包括什么时候删除缓存。

## 结束
多线程下载图片实际上已经差不多描述完了，重点就是线程的跳转和一些性能的问题，在拼接磁盘缓存路径的时候应该放在其他只会调用一些的方法中执行，并且创建一个类属性记录这个路径。


