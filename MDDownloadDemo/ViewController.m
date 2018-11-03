//
//  ViewController.m
//  MDDownloadDemo
//
//  Created by Acery on 2016/9/22.
//  Copyright © 2016年 Acery. All rights reserved.
//  使用多线程去执行下载任务（图片），同时缓存
//  需要修改占位图片

#import "ViewController.h"
#import "ACCellModel.h"

@interface ViewController ()

/**在内存中保存了所有图片*/
@property (strong, nonatomic ) NSMutableDictionary<NSString *,UIImage *> *images;

/**在内存中保存了所有cellItem*/
@property (strong, nonatomic ) NSMutableArray<ACCellModel *> *models;

/**请求缓存*/
@property (strong, nonatomic ) NSMutableDictionary<NSString *,NSBlockOperation *> *operations;

/**队列*/
@property (strong, nonatomic )NSOperationQueue *myQueue;


@end

@implementation ViewController


#pragma mark - lazy init
/****************************************************************************************************************/


- (NSMutableArray<ACCellModel *> *)models
{
    if (_models == nil)
    {
        NSString *path = [[NSBundle mainBundle]pathForResource:@"wow.plist" ofType:nil];
        
        NSArray *dataArray = [[NSArray alloc]initWithContentsOfFile:path];
        
        _models = [NSMutableArray array];
        
        for (NSDictionary *dict in dataArray)
        {
            ACCellModel *model = [ACCellModel modelWithDict:dict];
            [_models addObject:model];
        }
    }
    
    return _models;
}

- (NSMutableDictionary *)images
{
    if (_images == nil)
    {
        _images = [NSMutableDictionary dictionary];
    }
    
    return _images;
}

- (NSMutableDictionary *)operations
{
    if (_operations == nil)
    {
        _operations = [NSMutableDictionary dictionary];
    }
    
    return _operations;
}


- (NSOperationQueue *)myQueue
{
    if (_myQueue == nil)
    {
        _myQueue = [[NSOperationQueue alloc]init];
    }
    
    return _myQueue;
}

#pragma mark - view fun
/****************************************************************************************************************/


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.rowHeight = 50;
    
    self.tableView.bounds = CGRectMake(0, 0, 375, 200);
    
}

-(void)didReceiveMemoryWarning
{
    [self.images removeAllObjects];
}

#pragma mark - table delegate
/****************************************************************************************************************/

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.models.count;
}


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

            NSBlockOperation *downloadOp = self.operations[model.url];

            if (downloadOp)
            {
                //下载正在执行
                NSLog(@"正在下载");
            }
            else
            {
                //添加下载任务
                NSLog(@"下载");
                //下载文件

                //设置占位图片
                cell.imageView.image = [UIImage imageNamed:@"display"];


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

                        NSLog(@"main --- %@",[NSThread currentThread]);

                    });

                }];

                [self.operations setObject:downloadOp forKey:model.url];

                [self.myQueue addOperation:downloadOp];
                
            }

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

    /*z设置文字*/

    cell.textLabel.text = model.title;
    
    return cell;
}

-(UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [[UIView alloc]init];
}

@end
