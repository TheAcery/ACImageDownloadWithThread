//
//  ACCellModel.m
//  MDDownloadDemo
//
//  Created by Acery on 2018/9/22.
//  Copyright © 2018年 Acery. All rights reserved.
//

#import "ACCellModel.h"

@implementation ACCellModel

+(instancetype)modelWithDict:(NSDictionary *)dict
{
    ACCellModel *model = [[ACCellModel alloc]init];
    
    model.title = dict[@"title"];
    model.url = dict[@"url"];
    
    return model;
}

@end
