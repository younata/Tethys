import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import Foundation

@testable import TethysKit

final class InoreaderFeedServiceIntegrationSpec: QuickSpec {
    override func spec() {
        var subject: InoreaderFeedService!
        var httpClient: FakeHTTPClient!

        let baseURL = URL(string: "https://example.com")!

        beforeEach {
            httpClient = FakeHTTPClient()

            subject = InoreaderFeedService(httpClient: httpClient, baseURL: baseURL)
        }

        describe("articles(of:)") {
            var future: Future<Result<AnyCollection<Article>, TethysError>>!

            beforeEach {
                future = subject.articles(of: feedFactory())
            }

            describe("when the request succeeds with valid data") {
                context("teslarati") {
                    let data = try! Data(
                        contentsOf: Bundle(for: self.classForCoder)
                            .url(forResource: "InoreaderArticles_teslarati", withExtension: "json")!
                    )

                    var articles: [Article] = []

                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: data,
                            status: .ok,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))

                        articles = Array(future.value?.value ?? AnyCollection([]))
                    }

                    it("resolves the future with the parsed articles") {
                        expect(future).to(beResolved())
                        expect(future.value?.error).to(beNil())
                        expect(articles).to(haveCount(20))
                    }

                    describe("the first article") {
                        var article: Article?

                        beforeEach {
                            article = articles.first
                        }

                        it("correctly parses the first article") {
                            expect(article?.title).to(equal(
                                "NASA snubbed SpaceX, common sense to overpay Boeing for astronaut launches, says audit"
                            ))
                            expect(article?.link).to(equal(URL(string: "https://www.teslarati.com/nasa-snubbed-spacex-overpaid-boeing-astronaut-launches-audit/")))
                            expect(article?.content).to(equal(article?.summary))
                            expect(article?.summary).to(equal(
                                "<p>A detailed government audit has revealed that NASA went out of its way to overpay Boeing for its Commercial Crew Program (CCP) astronaut launch services, making a mockery of its fixed-price contract with the company and blatantly snubbing SpaceX throughout the process.</p> \n \n \n \n<div> \n<blockquote><p lang=\"en\" dir=\"ltr\">A step further, not only did NASA not try to give SpaceX an option to propose their own solution, they didn't even notify SpaceX before they arbitrarily changed Boeing's requirements. Altogether, Boeing has now received $5.1B to complete the same work SpaceX received $3.1B for. <a href=\"https://t.co/vm1v4I1Pzc\">pic.twitter.com/vm1v4I1Pzc</a></p>— Eric Ralph (@13ericralph31) <a href=\"https://twitter.com/13ericralph31/status/1195061715781611520?ref_src=twsrc%5Etfw\">November 14, 2019</a></blockquote></div><div><ins style=\"text-align:center;\"></ins></div> \n \n \n \n<p>Over the last several years, the NASA inspector general has published a number of increasingly discouraging reports about Boeing’s behavior and track-record as a NASA contractor, and November 14th’s report is possibly the most concerning yet. On November 14th, NASA’s Office of the Inspector General (OIG) published a damning audit titled <a href=\"https://oig.nasa.gov/docs/IG-20-005.pdf\">“NASA’s Management of Crew Transportation to the International Space Station [ISS]” (PDF)</a>. </p> \n \n \n \n<p>Offering more than 50 pages of detailed analysis of behavior that was at best inept and at worst deeply corrupt, OIG’s analysis uncovered some uncomfortable revelations about NASA’s relationship with Boeing in a different realm than usual: NASA’s Commercial Crew Program (CCP). Begun in the 2010s in an effort to develop multiple redundant commercial alternatives to the Space Shuttle, prematurely canceled before a US alternative was even on the horizon, the CCP ultimately awarded SpaceX and Boeing major development contracts in September 2014. </p> \n \n \n \n<a href=\"https://www.teslarati.com/wp-content/uploads/2019/07/Crew-Dragon-DM-1-ISS-arrival-030319-NASA-3-crop-2.jpg\" title=\"\"><img src=\"https://www.teslarati.com/wp-content/uploads/2019/07/Crew-Dragon-DM-1-ISS-arrival-030319-NASA-3-crop-2-1024x519.jpg\" alt=\"\"></a><em>Crew Dragon approaches the ISS on March 3rd during DM-1, the spacecraft’s uncrewed orbital launch debut.</em> (NASA)<a href=\"https://www.teslarati.com/wp-content/uploads/2019/11/Starliner-OFT-110319-Boeing-pre-fueling-1-crop.jpg\" title=\"\"><img src=\"https://www.teslarati.com/wp-content/uploads/2019/11/Starliner-OFT-110319-Boeing-pre-fueling-1-crop-1024x601.jpg\" alt=\"\"></a><em>Boeing’s Orbital Flight Test (OFT) Starliner spacecraft prepares for flight on November 3rd. </em>(Boeing)<p>NASA awarded fixed-cost contracts worth $4.2 billion and $2.6 billion to Boeing and SpaceX, respectively, to essentially accomplish the same goals: design, build, test, and fly new spacecraft capable of transporting NASA astronauts to and from the International Space Station (ISS). The intention behind fixed-price contracts was to hold contractors responsible for any delays they might incur over the development of human-rated spacecraft, a task NASA acknowledged as challenging but far from unprecedented.</p> \n \n \n \n<h3>Off the rails</h3> \n \n \n \n<p>The most likely trigger of the bizarre events that would unfold a few years down the road began in part on June 28th, 2015 and culminated on September 1st, 2016, the dates of the two catastrophic failures SpaceX’s Falcon 9 rocket has suffered since its 2010 debut. In the most generous possible interpretation of the OIG’s findings, NASA headquarters and CCP managers may have been shaken and not thinking on an even keel after SpaceX’s second major failure in a little over a year.</p> \n \n \n \n<div> \n<iframe allowfullscreen=\"allowfullscreen\" title=\"SpaceX - Static Fire Anomaly - AMOS-6 - 09-01-2016\" width=\"1000\" height=\"563\" src=\"https://www.youtube.com/embed/_BgJEXQkjNQ?feature=oembed\" frameborder=\"0\"></iframe> \n</div><p>Under this stress, the agency may have ignored common sense and basic contracting due-diligence, leading “numerous officials” to sign off on a plan that would subvert Boeing’s fixed-price contract, paying the company an additional $287 million (~7%) to prevent a perceived gap in NASA astronaut access to the ISS. This likely arose because NASA briefly believed that SpaceX’s failures could cause multiple years of delays, making Boeing the only available crew transporter provider for a significant period of time. Starliner was already delayed by more than a year, making it increasingly unlikely that Boeing <em>alone</em> would be able to ensure continuous NASA access to the ISS.</p> \n \n \n \n<p>As NASA argued in its attempted response and defense to the audit, “the final price [increase] was agreed to by NASA and Boeing and was reviewed and approved by numerous NASA officials at the Kennedy Space Center and Headquarters”. In the heat of the moment, perhaps those officials forgot that Boeing had already purchased several Russian Soyuz seats to sell to NASA or tourists, and perhaps those officials missed the simple fact that those seats and some elementary schedule tweaks could have almost entirely alleviated the perceived “access gap” with minimal cost and effort.</p> \n \n \n \n<div> \n<blockquote><p lang=\"en\" dir=\"ltr\">tl:dr: \"We can neither confirm or deny\", basically confirming that Boeing seriously threatened to quit/leave the Commercial Crew Program if NASA didn't pay it more. <br><br>Verges on extortion, if you ask me. Just pathetic. <a href=\"https://t.co/klB9MiJT5M\">https://t.co/klB9MiJT5M</a></p>— Eric Ralph (@13ericralph31) <a href=\"https://twitter.com/13ericralph31/status/1195116772325617664?ref_src=twsrc%5Etfw\">November 14, 2019</a></blockquote></div><p>The OIG audit further implied that the timing of a Boeing proposal – submitted just days after NASA agreed to pay the company extra to prevent that access gap – was suspect.</p> \n \n \n \n<p><strong><em>“Five days after NASA committed to pay $287.2 million in price increases for four commercial crew missions, Boeing submitted an official proposal to sell NASA up to five Soyuz seats for $373.5 million for missions during the same time period. In total, Boeing received $660.7 million above the fixed prices set in the CCtCap pricing tables to pay for an accelerated production timetable for four crew missions and five Soyuz seats.”</em></strong><br><br><a href=\"https://oig.nasa.gov/docs/IG-20-005.pdf\">NASA OIG — November 14th, 2019 [PDF]</a></p> \n \n \n \n<p>In other words, NASA officials somehow failed to realize or remember that Boeing owned multiple Soyuz seats during “prolonged negotiations” (p. 24) <em>with Boeing</em> and subsequently awarded Boeing an additional $287M to expedite Starliner production and preparations, thus averting an access gap. The very next week, Boeing asked NASA if it wanted to buy five Soyuz seats it had already acquired to send NASA astronauts to the ISS. </p> \n \n \n \n<p>Bluntly speaking, this series of events has exactly three explanations, none of them heartwarming.</p> \n \n \n \n<ol><li>Boeing intentionally withheld an obvious (partial) solution to a perceived gap in astronaut access to the ISS, exploiting NASA’s panic to extract a ~7% premium from its otherwise fixed-price Starliner development contract. </li><li>Through gross negligence and a lack of basic contracting due-diligence, NASA ignored obvious (and cheaper) possible solutions at hand, taking Boeing’s word for granted and opening up the piggy bank.</li><li>A farcical ‘crew access analysis’ study ignored multiple obvious and preferable solutions to give “numerous NASA officials” an excuse to violate fixed-price contracting principles and pay Boeing a substantial premium. </li></ol><div> \n<blockquote><p lang=\"en\" dir=\"ltr\">Hmmm. A recent report found that from July 2014 through Sept. 2018, NASA assessed Boeing's performance on development of the SLS core stage as \"good,\" \"very good,\" and \"excellent\" at various times. The agency gave Boeing $271 million in award fees.<a href=\"https://t.co/GBvxLq3gIv\">https://t.co/GBvxLq3gIv</a></p>— Eric Berger (@SciGuySpace) <a href=\"https://twitter.com/SciGuySpace/status/1150826372593532930?ref_src=twsrc%5Etfw\">July 15, 2019</a></blockquote></div><h3>Extortion with a friendly smile</h3> \n \n \n \n<p>The latter explanation, while possibly the worst and most corruption-laden, is arguably the likeliest choice based on the history of NASA’s relationship with Boeing. In fact, a July 2019 report from the US Government Accountability Office (GAO) revealed that NASA was consistently paying Boeing hundreds of millions of dollars worth of “award fees” as part of the company’s SLS booster (core stage) production contract, which is no less than four years behind schedule and $1.8 billion over budget. From 2014 to 2018, NASA awarded Boeing a total of $271M in award fees, a practice meant to award a given contractor’s excellent performance. </p> \n \n \n \n<p>In several of those years, NASA reviews reportedly described Boeing’s performance as “good”, “very good”, and “excellent”, all while Boeing repeatedly fumbled SLS core stage production, adding <em>years</em> of delays to the SLS rocket’s launch debut. This is to say that “numerous NASA officials” were also presumably more than happy to give Boeing hundreds of millions of dollars in awards even as the company was and is clearly a big reason why the SLS program continues to fail to deliver.</p> \n \n \n \n<div> \n<iframe allowfullscreen=\"allowfullscreen\" title=\"Boeing performs crew capsule abort test\" width=\"1000\" height=\"563\" src=\"https://www.youtube.com/embed/tit8ktqc5Cw?feature=oembed\" frameborder=\"0\"></iframe> \n</div><a href=\"https://www.teslarati.com/boeing-starliner-abort-test-spacex-crew-dragon-static-fire/\"><em>Boeing completed a most-successful Starliner pad abort test earlier this month, the spacecraft’s first integrated flight of any kind.</em></a><p>Ultimately, although NASA’s concern about SpaceX’s back-to-back Falcon 9 failures and some combination of ineptitude, ignorance, and corruption all clearly played a role, the fact remains that NASA – according to the inspector general – <em>never</em> approached SpaceX as part of their 2016/2017 efforts prevent a ‘crew access gap’. Given that the CCP has two partners, that decision was highly improper regardless of the circumstances and is made even more inexplicable by the fact that NASA was apparently well aware that SpaceX’s Crew Dragon had significantly shorter lead times and cost far less than Starliner. </p> \n \n \n \n<p>This would have meant that had NASA approached SpaceX to attempt to mitigate the access gap, SpaceX could have almost certainly done it significantly cheaper and faster, or at minimum injected a bit of good-faith competition into the endeavor.</p> \n \n \n \n<div> \n<blockquote><p lang=\"en\" dir=\"ltr\">WOW. \"According to several NASA officials, a significant consideration for paying Boeing such a premium was to ensure the contractor continued as a second crew transportation provider.\"<br><br>Did Boeing threaten to quit?</p>— Eric Berger (@SciGuySpace) <a href=\"https://twitter.com/SciGuySpace/status/1195061305654304769?ref_src=twsrc%5Etfw\">November 14, 2019</a></blockquote></div><p>Finally and perhaps most disturbingly of all, NASA OIG investigators were told by “several NASA officials” that – in spite of several preferable alternatives – they ultimately chose to sign off Boeing’s demanded price increases because they were worried that Boeing would <em>quit the Commercial Crew Program entirely</em> without it. Boeing and NASA unsurprisingly denied this in their official responses to the OIG audit, but a US government inspector generally <em>would never </em>publish such a claim without substantial confidence and plenty of evidence to support it.</p> \n \n \n \n<p>According to OIG sources, “senior CCP officials believed that due to financial considerations, Boeing could not continue as a commercial crew provider unless the contractor received the higher prices.” A lot remains unsaid, like why those officials believed that Boeing’s full withdrawal from CCP was a serious risk and how they came to that conclusion, enough to make it impossible to conclude that Boeing actually <em>threatened</em> to quit in lieu of NASA payments. </p> \n \n \n \n<a href=\"https://www.teslarati.com/wp-content/uploads/2019/11/Starship-2019-Saturn-render-SpaceX-1.jpg\" title=\"\"><img src=\"https://www.teslarati.com/wp-content/uploads/2019/11/Starship-2019-Saturn-render-SpaceX-1-1024x576.jpg\" alt=\"\"></a><p>All things considered, these fairly damning revelations should by no means take away from the excellent work Boeing engineers and technicians are trying to do to design, build, and launch Starliner. However, they do serve to draw a fine line between the mindsets and motivations of Boeing and SpaceX. One puts profit, shareholders, and itself above all else, while the other is trying hard to lower the cost of spaceflight and enable a sustainable human presence on the Moon, Mars, and beyond.</p> \n \n \n \n<p><a href=\"https://api.pico.tools/pn/teslarati/37r7aa7x\"><em>Check out Teslarati’s newsletters</em></a><em> for prompt updates, on-the-ground perspectives, and unique glimpses of SpaceX’s rocket launch and recovery processes</em>.</p> \n<p>The post <a href=\"https://www.teslarati.com/nasa-snubbed-spacex-overpaid-boeing-astronaut-launches-audit/\">NASA snubbed SpaceX, common sense to overpay Boeing for astronaut launches, says audit</a> appeared first on <a href=\"https://www.teslarati.com\">TESLARATI</a>.</p>"
                            ))

                            expect(article?.authors).to(equal([Author("Eric Ralph")]))
                            expect(article?.identifier).to(equal("tag:google.com,2005:reader/item/000000052eb8f4d3"))
                            expect(article?.read).to(beTrue())
                            expect(article?.published).to(equal(Date(timeIntervalSince1970: 1573811739)))
                            expect(article?.updated).to(equal(Date(timeIntervalSince1970: 1573822246)))
                        }
                    }
                }

                context("xkcd") {
                    let data = try! Data(
                        contentsOf: Bundle(for: self.classForCoder)
                            .url(forResource: "InoreaderArticles_xkcd", withExtension: "json")!
                    )

                    var articles: [Article] = []

                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: data,
                            status: .ok,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))

                        articles = Array(future.value?.value ?? AnyCollection([]))
                    }

                    it("resolves the future with the parsed articles") {
                        expect(future).to(beResolved())
                        expect(future.value?.error).to(beNil())
                        expect(articles).to(haveCount(20))
                    }

                    it("correctly parses the first article") {
                        let article = articles.first
                        expect(article?.title).to(equal("AI Hiring Algorithm"))
                        expect(article?.link).to(equal(URL(string: "https://xkcd.com/2237/")))
                        expect(article?.summary).to(equal("<img src=\"https://imgs.xkcd.com/comics/ai_hiring_algorithm.png\" title=\"So glad Kate over in R&amp;D pushed for using the AlgoMaxAnalyzer to look into this. Hiring her was a great decisio- waaaait.\" alt=\"So glad Kate over in R&amp;D pushed for using the AlgoMaxAnalyzer to look into this. Hiring her was a great decisio- waaaait.\">"))
                        expect(article?.authors).to(beEmpty())
                        expect(article?.read).to(beTrue())
                        expect(article?.published).to(equal(Date(timeIntervalSince1970: 1575417600)))
                        expect(article?.updated).to(equal(Date(timeIntervalSince1970: 0)))
                    }
                }
            }
        }
    }
}
