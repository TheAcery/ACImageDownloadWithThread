//
//  ACCellModel.h
//  MDDownloadDemo
//
//  Created by Acery on 2016/9/22.
//  Copyright © 2018年 Acery. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ACCellModel : NSObject

@property (strong ,nonatomic) NSString *url;

@property (strong ,nonatomic) NSString *title;


+(instancetype)modelWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
